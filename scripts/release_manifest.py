"""Host-only signed release schema. No I/O, key discovery or crypto implementation.

Verifier and opkg comparison are mandatory caller-supplied trusted ports.
See core 6.12 / SIGNED_RELEASES.md. Inputs are not installation authorization.
"""
import hashlib
import json
import re

MANIFEST_BYTES = 65536
SIGNATURE_BYTES = 512
LIST_BYTES = 262144
MAX_INT = 2147483647


class Rejected(ValueError):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


def require(condition, code='invalid_manifest'):
    if not condition:
        raise Rejected(code)


def fields(value, names):
    require(type(value) is dict and set(value) == set(names.split()))


def string(value, limit, pattern=None):
    require(type(value) is str)
    try:
        size = len(value.encode('utf-8'))
    except UnicodeError as exc:
        raise Rejected('invalid_manifest') from exc
    require(0 < size <= limit and all(ord(c) >= 32 and ord(c) != 127 for c in value))
    if pattern:
        require(re.fullmatch(pattern, value, flags=re.ASCII) is not None)
    return value


def array(value, maximum, minimum=0):
    require(type(value) is list and minimum <= len(value) <= maximum)
    return value


def integer(value, minimum=0):
    require(type(value) is int and minimum <= value <= MAX_INT)
    return value


def decode(raw, limit, depth=8):
    require(type(raw) is bytes)
    require(len(raw) <= limit, 'response_too_large')
    def pairs(items):
        result = {}
        for key, val in items:
            require(key not in result)
            result[key] = val
        return result
    def number(text):
        require(re.fullmatch(r'0|[1-9][0-9]{0,9}', text) is not None)
        return integer(int(text))
    def bad(_):
        raise Rejected('invalid_manifest')
    try:
        text = raw.decode('utf-8')
        require(not text.startswith('\ufeff'))
        nesting = 0
        quoted = escaped = False
        for c in text:
            if quoted:
                if escaped:
                    escaped = False
                elif c == '\\':
                    escaped = True
                elif c == '"':
                    quoted = False
            elif c == '"':
                quoted = True
            elif c in '[{':
                nesting += 1
                require(nesting <= depth)
            elif c in ']}':
                nesting -= 1
        result = json.loads(text, object_pairs_hook=pairs, parse_int=number,
                            parse_float=bad, parse_constant=bad)
        def walk(v):
            if type(v) is str:
                # Empty strings are allowed by JSON, not by schema string fields.
                if v:
                    string(v, limit)
            elif type(v) is dict:
                for k, val in v.items():
                    if k:
                        string(k, limit)
                    walk(val)
            elif type(v) is list:
                for val in v:
                    walk(val)
        walk(result)
        return result
    except (UnicodeError, RecursionError, json.JSONDecodeError) as exc:
        raise Rejected('invalid_manifest') from exc


def semver(value):
    string(value, 128, r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')
    return tuple(integer(int(x)) for x in value.split('.'))


def compare(a, b, scheme, opkg):
    if scheme == 'semver3':
        x, y = semver(a), semver(b)
        return (x > y) - (x < y)
    require(scheme == 'opkg', 'unsupported_format')
    string(a, 128)
    string(b, 128)
    result = opkg(a, b)
    require(type(result) is int and result in (-1, 0, 1), 'internal')
    return result


def package_name(value):
    return string(value, 128, r'[a-z0-9][a-z0-9+.-]*')


def dependency(dep):
    fields(dep, 'name op version')
    package_name(dep['name'])
    require(dep['op'] in ('any', 'eq', 'ge', 'gt', 'le', 'lt'))
    if dep['op'] == 'any':
        require(dep['version'] is None)
    else:
        string(dep['version'], 128)


def satisfies(version, dep, opkg):
    if dep['op'] == 'any':
        return True
    c = compare(version, dep['version'], 'opkg', opkg)
    return {'eq': c == 0, 'ge': c >= 0, 'gt': c > 0,
            'le': c <= 0, 'lt': c < 0}[dep['op']]


def validate(doc, repository, tag, opkg):
    fields(doc, 'format repository tag source_commit platform components packages')
    require(doc['format'] == 'openwrt-extension-release/1', 'unsupported_format')
    require(string(doc['repository'], 200) == repository)
    require(string(doc['tag'], 256) == tag)
    string(doc['source_commit'], 40, r'[0-9a-f]{40}')
    p = doc['platform']
    fields(p, 'profile package_format openwrt target architecture libc lua kernel_abi firmware')
    string(p['profile'], 96, r'[a-z0-9][a-z0-9._-]*')
    require(p['package_format'] == 'ipk', 'unsupported_format')
    for key, limit in [('openwrt', 32), ('target', 64), ('architecture', 64), ('lua', 16)]:
        string(p[key], limit)
    fields(p['libc'], 'name version')
    for v in p['libc'].values():
        string(v, 64)
    if p['kernel_abi'] is not None:
        string(p['kernel_abi'], 128)
    firmware = {}
    for f in array(p['firmware'], 64):
        fields(f, 'name version')
        name = package_name(f['name'])
        require(name not in firmware)
        firmware[name] = string(f['version'], 128)
    packages, assets = {}, set()
    for pkg in array(doc['packages'], 64, 1):
        fields(pkg, 'name version architecture asset bytes sha256 depends')
        name = package_name(pkg['name'])
        require(name not in packages and name not in firmware)
        packages[name] = pkg
        string(pkg['version'], 128)
        string(pkg['architecture'], 64)
        asset = string(pkg['asset'], 192, r'[A-Za-z0-9][A-Za-z0-9._+-]*\.ipk')
        require('..' not in asset and asset not in assets)
        assets.add(asset)
        integer(pkg['bytes'], 1)
        string(pkg['sha256'], 64, r'[0-9a-f]{64}')
        if name.startswith('kmod-'):
            require(p['kernel_abi'] is not None)
        for dep in array(pkg['depends'], 64):
            dependency(dep)
    visiting, done = set(), set()
    def visit(name):
        require(name not in visiting)
        if name in done or name in firmware:
            return
        require(name in packages)
        visiting.add(name)
        for dep in packages[name]['depends']:
            visit(dep['name'])
        visiting.remove(name)
        done.add(name)
    for name in packages:
        visit(name)
    components, roots = set(), set()
    for comp in array(doc['components'], 64, 1):
        fields(comp, 'publisher name package version_scheme upgrade_from requires_core_api data_policy')
        for key in ('publisher', 'name'):
            string(comp[key], 64, r'[A-Za-z0-9][A-Za-z0-9_-]*')
        identity = comp['publisher'] + '/' + comp['name']
        package_name(comp['package'])
        require(identity not in components and comp['package'] not in roots and comp['package'] in packages)
        roots.add(comp['package'])
        components.add(identity)
        scheme = comp['version_scheme']
        require(scheme in ('semver3', 'opkg'), 'unsupported_format')
        compare(packages[comp['package']]['version'], packages[comp['package']]['version'], scheme, opkg)
        intervals = array(comp['upgrade_from'], 16, 1)
        for i, interval in enumerate(intervals):
            fields(interval, 'min_inclusive max_exclusive')
            lo, hi = interval['min_inclusive'], interval['max_exclusive']
            compare(lo, lo, scheme, opkg)
            require(hi is None or compare(lo, hi, scheme, opkg) < 0)
            for previous in intervals[:i]:
                a, b = previous['min_inclusive'], previous['max_exclusive']
                require((b is not None and compare(b, lo, scheme, opkg) <= 0) or
                        (hi is not None and compare(hi, a, scheme, opkg) <= 0))
        if comp['requires_core_api'] is not None:
            string(comp['requires_core_api'], 64)
        fields(comp['data_policy'], 'action rollback')
        require(comp['data_policy']['action'] in ('preserve', 'migrate'))
        require(comp['data_policy']['rollback'] in ('package_only', 'restore_backup'))
    return doc


def verified_manifest(raw, signature, repository, tag, keys, verifier, opkg):
    require(type(raw) is bytes and len(raw) <= MANIFEST_BYTES, 'response_too_large')
    sig = decode(signature, SIGNATURE_BYTES)
    fields(sig, 'algorithm key_id signature')
    require(sig['algorithm'] == 'ed25519', 'unsupported_format')
    key_id = string(sig['key_id'], 64, r'[0-9a-f]{64}')
    signature_hex = string(sig['signature'], 128, r'[0-9a-f]{128}')
    require(key_id in keys, 'unknown_key')
    key = keys[key_id]
    require(repository in key['repositories'], 'unknown_key')
    public = key['public']
    require(type(public) is bytes and len(public) == 32 and
            hashlib.sha256(public).hexdigest() == key_id, 'unknown_key')
    require(verifier(public, raw, bytes.fromhex(signature_hex)) is True, 'bad_signature')
    doc = validate(decode(raw, MANIFEST_BYTES), repository, tag, opkg)
    require(all(c['publisher'] in key['publishers'] for c in doc['components']), 'unknown_key')
    return doc, hashlib.sha256(raw).hexdigest()


def platform_matches(platform, local):
    for field in ('profile', 'package_format', 'openwrt', 'target', 'architecture', 'libc', 'lua'):
        require(platform[field] == local['platform'][field], 'incompatible_platform')
    if platform['kernel_abi'] is not None:
        require(platform['kernel_abi'] == local['platform']['kernel_abi'], 'incompatible_platform')
    installed = local['installed']
    for dep in platform['firmware']:
        require(dep['name'] in installed and installed[dep['name']]['version'] == dep['version'], 'dependency_conflict')


def compatible(doc, comp, local, opkg):
    """Return selected package names, keeping compatible installed dependencies.

    local is a trusted snapshot, including complete installed reverse dependencies.
    This checks metadata, not actual archive contents or migration execution.
    """
    platform = doc['platform']
    platform_matches(platform, local)
    installed = local['installed']
    root = comp['package']
    require(root in installed, 'incompatible_platform')
    require(comp['requires_core_api'] is None or comp['requires_core_api'] in local['core_apis'], 'incompatible_platform')
    current = installed[root]['version']
    scheme = comp['version_scheme']
    require(any(compare(current, i['min_inclusive'], scheme, opkg) >= 0 and
                (i['max_exclusive'] is None or compare(current, i['max_exclusive'], scheme, opkg) < 0)
                for i in comp['upgrade_from']), 'incompatible_platform')
    if comp['data_policy']['action'] == 'migrate':
        require((root, current, next(p['version'] for p in doc['packages'] if p['name'] == root))
                in local['migrations'], 'incompatible_platform')
    packages = {p['name']: p for p in doc['packages']}
    selected = {root}
    # Monotonic fixed point: each available package is selected at most once.
    while True:
        added = set()
        for name in sorted(selected):
            pkg = packages[name]
            require(pkg['architecture'] in ('all', local['platform']['architecture']), 'incompatible_platform')
            for dep in pkg['depends']:
                n = dep['name']
                if n in selected:
                    value = packages[n]
                else:
                    value = installed.get(n)
                if value is None or not satisfies(value['version'], dep, opkg):
                    require(n in packages and satisfies(packages[n]['version'], dep, opkg), 'dependency_conflict')
                    added.add(n)
        added -= selected
        if not added:
            break
        selected |= added
    effective = dict(installed)
    effective.update({name: packages[name] for name in selected})
    # Includes unchanged modules: shared library upgrades cannot break them.
    for pkg in effective.values():
        for dep in pkg['depends']:
            require(dep['name'] in effective and satisfies(effective[dep['name']]['version'], dep, opkg), 'dependency_conflict')
    return sorted(selected)
