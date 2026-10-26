#!/usr/bin/env python3
"""Offline oracle/fault tests. Fake signatures are NOT Ed25519 evidence."""
from copy import deepcopy
import hashlib
import json
import unittest
from release_manifest import (Rejected, decode, validate, verified_manifest, compatible,
                              MANIFEST_BYTES, SIGNATURE_BYTES, LIST_BYTES, semver)
from release_discovery import Discovery, Response, DEADLINE_MS, FRESH_MS

REPO = 'example/extensions'
ID = 'example/schoolbell'
PUBLIC = bytes(range(32))
KEY_ID = hashlib.sha256(PUBLIC).hexdigest()
KEYS = {KEY_ID: dict(public=PUBLIC, repositories=[REPO], publishers=['example'])}
REGISTRY = {ID: dict(repository=REPO, package='modbus-schoolbell', version_scheme='semver3'),
            'example/rover': dict(repository=REPO, package='modbus-rover', version_scheme='semver3')}


def dump(value):
    return json.dumps(value, separators=(',', ':')).encode()


def fake_signature(raw):
    # Deliberately a deterministic test oracle, never accepted by real Ed25519.
    return hashlib.sha512(b'test-only:' + raw).digest()


def signature(raw):
    return dump(dict(algorithm='ed25519', key_id=KEY_ID, signature=fake_signature(raw).hex()))


def verify(public, raw, sig):
    return public == PUBLIC and sig == fake_signature(raw)


def opkg(a, b):
    # Only synthetic numeric versions in fixtures. Native opkg ordering deferred.
    x, y = tuple(map(int, a.split('.'))), tuple(map(int, b.split('.')))
    return (x > y) - (x < y)


def package(name='modbus-schoolbell', version='5.2.0', depends=None):
    return dict(name=name, version=version, architecture='all', asset=name + '_' + version + '_all.ipk',
                bytes=32, sha256=hashlib.sha256((name + version).encode()).hexdigest(), depends=depends or [])


def component(name='schoolbell', package_name='modbus-schoolbell'):
    return dict(publisher='example', name=name, package=package_name, version_scheme='semver3',
                upgrade_from=[dict(min_inclusive='5.0.0', max_exclusive='6.0.0')],
                requires_core_api=None, data_policy=dict(action='preserve', rollback='package_only'))


def manifest(version='5.2.0', tag='release-a'):
    return dict(format='openwrt-extension-release/1', repository=REPO, tag=tag, source_commit='a' * 40,
                platform=dict(profile='test-platform', package_format='ipk', openwrt='19.07.9',
                              target='ramips/mt76x8', architecture='mipsel_24kc',
                              libc=dict(name='musl', version='1.1'), lua='5.1', kernel_abi=None, firmware=[]),
                components=[component()], packages=[package(version=version)])


def local():
    return dict(platform=manifest()['platform'], installed={
        'modbus-schoolbell': dict(version='5.1.2', depends=[]),
        'modbus-rover': dict(version='1.0.0', depends=[])}, core_apis=[], migrations=[])


def dep(name, op='any', version=None):
    return dict(name=name, op=op, version=version)


class Harness:
    def __init__(self, docs=None):
        self.now = 1000
        self.calls = []
        self.responses = {}
        self.docs = docs if docs is not None else [manifest()]
        self.set_page(1, self.docs)
        self.model = Discovery(REGISTRY, local(), KEYS, self.fetch, lambda: self.now, verify, opkg)

    def set_page(self, page, docs, next_page=0):
        releases = []
        for doc in docs:
            stem = 'release-' + doc['platform']['profile']
            names = [stem + '.json', stem + '.sig'] + [p['asset'] for p in doc['packages']]
            releases.append(dict(tag_name=doc['tag'], draft=False, prerelease=False,
                                 assets=[dict(name=n) for n in names]))
            raw = dump(doc)
            self.responses[('asset', doc['tag'], stem + '.json')] = Response(raw)
            self.responses[('asset', doc['tag'], stem + '.sig')] = Response(signature(raw))
        self.responses[('list', page)] = Response(dump(releases), next_page=next_page)

    def fetch(self, req):
        self.calls.append(req)
        key = ('list', req.page) if req.kind == 'list' else ('asset', req.tag, req.asset)
        response = self.responses[key]
        return response(req) if callable(response) else response

    def start(self):
        return self.model.check(ID, admin=True, csrf=True)

    def drain(self):
        for _ in range(100):
            if not self.model.step():
                return self.status()
        raise AssertionError('unbounded search')

    def status(self):
        return self.model.status(ID, authenticated=True)

    def run(self):
        self.start()
        return self.drain()


class ManifestTests(unittest.TestCase):
    def check(self, doc):
        raw = dump(doc)
        return verified_manifest(raw, signature(raw), REPO, doc['tag'], KEYS, verify, opkg)[0]

    def reject(self, doc, code='invalid_manifest'):
        with self.assertRaises(Rejected) as ctx:
            self.check(doc)
        self.assertEqual(ctx.exception.code, code)

    def test_exact_bytes_and_verifier_order(self):
        raw = dump(manifest())
        seen = []
        def spy(key, data, sig):
            seen.append(data)
            return verify(key, data, sig)
        verified_manifest(raw, signature(raw), REPO, 'release-a', KEYS, spy, opkg)
        self.assertEqual(seen, [raw])
        for altered in (raw + b' ', raw.replace(b'5.2.0', b'5.3.0')):
            with self.assertRaisesRegex(Rejected, 'bad_signature'):
                verified_manifest(altered, signature(raw), REPO, 'release-a', KEYS, spy, opkg)
        with self.assertRaisesRegex(Rejected, 'bad_signature'):
            verified_manifest(b'not-json', signature(raw), REPO, 'release-a', KEYS, spy, opkg)

    def test_trust_scopes_and_fail_closed_verifier(self):
        raw = dump(manifest())
        for keys in ({}, {KEY_ID: dict(KEYS[KEY_ID], repositories=[])},
                     {KEY_ID: dict(KEYS[KEY_ID], publishers=[])},
                     {KEY_ID: dict(KEYS[KEY_ID], public=b'x' * 32)}):
            with self.assertRaisesRegex(Rejected, 'unknown_key'):
                verified_manifest(raw, signature(raw), REPO, 'release-a', keys, verify, opkg)
        with self.assertRaisesRegex(Rejected, 'bad_signature'):
            verified_manifest(raw, signature(raw), REPO, 'release-a', KEYS, lambda *_: 1, opkg)

    def test_byte_limits(self):
        raw = dump(manifest())
        padded = raw + b' ' * (MANIFEST_BYTES - len(raw))
        sig = signature(padded)
        verified_manifest(padded, sig + b' ' * (SIGNATURE_BYTES - len(sig)), REPO, 'release-a', KEYS, verify, opkg)
        for data, sigdata in ((padded + b' ', signature(padded)), (raw, b' ' * 513)):
            with self.assertRaisesRegex(Rejected, 'response_too_large'):
                verified_manifest(data, sigdata, REPO, 'release-a', KEYS, verify, opkg)

    def test_strict_json_lexical(self):
        bad = [b'{"a":1,"a":2}', b'\xef\xbb\xbf{}', b'"\xff"', b'{"x":NaN}',
               b'{"x":1e0}', b'{"x":1.0}', b'{"x":-0}', b'{"x":2147483648}',
               b'"\\ud800"', b'"\\u0000"', b'{"\\u0001":0}', b'[[[[[[[[[]]]]]]]]]']
        for raw in bad:
            with self.subTest(raw=raw), self.assertRaises(Rejected):
                decode(raw, 65536)
        self.assertEqual(decode(b'[[[[[[[[]]]]]]]]', 100), [[[[[[[[]]]]]]]])
        self.assertEqual(decode(b'{"x":"[\\\"{"}', 100), {'x': '["{'})

    def test_fields_types_and_enums(self):
        for path, value in [(['extra'], 1), (['packages', 0, 'bytes'], True),
                            (['packages', 0, 'bytes'], 0), (['packages', 0, 'bytes'], 2147483648),
                            (['packages', 0, 'asset'], '../evil.ipk'),
                            (['packages', 0, 'asset'], 'evil\\a.ipk'),
                            (['source_commit'], 'A' * 40), (['platform', 'libc', 'version'], ''),
                            (['components', 0, 'data_policy', 'action'], 'execute')]:
            doc = manifest()
            target = doc
            for key in path[:-1]:
                target = target[key]
            target[path[-1]] = value
            with self.subTest(path=path, value=value):
                self.reject(doc)
        doc = manifest(); doc['format'] = 'future/2'
        self.reject(doc, 'unsupported_format')
        doc = manifest(); del doc['components'][0]['requires_core_api']
        self.reject(doc)

    def test_count_and_string_boundaries(self):
        doc = manifest()
        doc['packages'] += [package('lib' + str(i), '1.0.0') for i in range(63)]
        self.check(doc)
        doc['packages'].append(package('too-many'))
        self.reject(doc)
        doc = manifest(); doc['components'][0]['name'] = 'x' * 64
        self.check(doc)
        doc['components'][0]['name'] += 'x'
        self.reject(doc)
        doc = manifest(); doc['platform']['target'] = 'я' * 32
        self.check(doc)
        doc['platform']['target'] += 'я'
        self.reject(doc)

    def test_graph_duplicates_and_cycles(self):
        for kind in ('package', 'component', 'asset', 'cycle', 'dangling', 'firmware'):
            doc = manifest()
            if kind == 'package': doc['packages'] *= 2
            elif kind == 'component': doc['components'] *= 2
            elif kind == 'asset': doc['packages'].append(dict(package('lib'), asset=doc['packages'][0]['asset']))
            elif kind == 'cycle': doc['packages'][0]['depends'] = [dep('modbus-schoolbell')]
            elif kind == 'dangling': doc['packages'][0]['depends'] = [dep('absent')]
            else: doc['platform']['firmware'] = [dict(name='modbus-schoolbell', version='5.1.2')]
            with self.subTest(kind=kind): self.reject(doc)

    def test_versions_and_upgrade_ranges(self):
        for v in ('5.01.0', '5.0', '5.0.0-beta', '2147483648.0.0', '５.0.0'):
            with self.assertRaises(Rejected): semver(v)
        doc = manifest(); ranges = doc['components'][0]['upgrade_from']
        ranges.append(dict(min_inclusive='5.5.0', max_exclusive=None))
        self.reject(doc)
        ranges[1]['min_inclusive'] = '6.0.0'
        self.check(doc)
        ranges[0]['max_exclusive'] = ranges[0]['min_inclusive']
        self.reject(doc)

    def test_kmod_requires_abi(self):
        doc = manifest(); doc['packages'].append(package('kmod-test'))
        self.reject(doc)
        doc['platform']['kernel_abi'] = '4.14-exact'
        self.check(doc)

    def test_signature_shape_and_scope(self):
        raw = dump(manifest())
        for change in (dict(algorithm='ssh-ed25519'), dict(key_id='B' * 64),
                       dict(signature='00'), dict(extra=True)):
            sig = json.loads(signature(raw)); sig.update(change)
            with self.assertRaises(Rejected):
                verified_manifest(raw, dump(sig), REPO, 'release-a', KEYS, verify, opkg)
        for repo, tag in ((REPO, 'wrong-tag'), ('wrong/repo', 'release-a')):
            with self.assertRaises(Rejected):
                verified_manifest(raw, signature(raw), repo, tag, KEYS, verify, opkg)


class DependencyTests(unittest.TestCase):
    def test_shared_dependency_preserved_then_conflict(self):
        doc, ctx = manifest(), local()
        doc['packages'][0]['depends'] = [dep('libshared', 'ge', '1.0.0')]
        doc['packages'].append(package('libshared', '2.0.0'))
        ctx['installed']['libshared'] = dict(version='1.0.0', depends=[])
        ctx['installed']['modbus-rover']['depends'] = [dep('libshared', 'lt', '2.0.0')]
        self.assertEqual(compatible(doc, doc['components'][0], ctx, opkg), ['modbus-schoolbell'])
        doc['packages'][0]['depends'][0]['version'] = '2.0.0'
        with self.assertRaisesRegex(Rejected, 'dependency_conflict'):
            compatible(doc, doc['components'][0], ctx, opkg)
        ctx['installed']['modbus-rover']['depends'] = []
        self.assertEqual(compatible(doc, doc['components'][0], ctx, opkg), ['libshared', 'modbus-schoolbell'])

    def test_only_selected_module_closure(self):
        doc = manifest()
        doc['packages'] += [package('modbus-rover', '2.0.0'), package('unused', '1.0.0')]
        doc['components'].append(component('rover', 'modbus-rover'))
        self.assertEqual(compatible(doc, doc['components'][0], local(), opkg), ['modbus-schoolbell'])

    def test_profile_api_migration_and_arch(self):
        for kind in ('platform', 'api', 'migration', 'arch', 'firmware', 'upgrade'):
            doc = manifest()
            if kind == 'platform': doc['platform']['openwrt'] = 'other'
            elif kind == 'api': doc['components'][0]['requires_core_api'] = 'unknown'
            elif kind == 'migration': doc['components'][0]['data_policy']['action'] = 'migrate'
            elif kind == 'arch': doc['packages'][0]['architecture'] = 'arm'
            elif kind == 'firmware': doc['platform']['firmware'] = [dict(name='libc', version='9')]
            else: doc['components'][0]['upgrade_from'][0]['min_inclusive'] = '6.0.0'
            with self.subTest(kind=kind), self.assertRaises(Rejected):
                compatible(doc, doc['components'][0], local(), opkg)


class DiscoveryTests(unittest.TestCase):
    def test_async_join_and_no_io_in_status(self):
        h = Harness(); first = h.start()
        self.assertTrue(first['accepted']); self.assertEqual(h.calls, [])
        self.assertEqual(first, h.start())
        self.assertEqual(h.model.check('example/rover', admin=True, csrf=True)['error'], 'busy')
        for _ in range(5): self.assertEqual(h.status()['state'], 'checking')
        self.assertEqual(h.calls, [])
        result = h.drain()
        self.assertEqual(result['result'], 'update_available')
        self.assertEqual(result['candidate']['version'], '5.2.0')
        self.assertTrue(result['scan_complete'])
        self.assertEqual(len(h.calls), 3)
        self.assertFalse(any(r.asset.endswith('.ipk') for r in h.calls))

    def test_selection_numeric_not_release_order(self):
        h = Harness([manifest('5.9.0', 'z'), manifest('5.10.0', 'a'), manifest('5.2.0', 'b')])
        self.assertEqual(h.run()['candidate']['version'], '5.10.0')

    def test_incompatible_newer_and_up_to_date(self):
        self.assertEqual(Harness([manifest('5.1.2')]).run()['result'], 'up_to_date')
        doc = manifest('6.0.0'); doc['components'][0]['upgrade_from'][0]['min_inclusive'] = '5.5.0'
        self.assertEqual(Harness([doc]).run()['result'], 'incompatible')
        h = Harness([manifest('5.1.2')]); h.docs[0]['platform']['openwrt'] = 'wrong'
        h.set_page(1, h.docs)
        self.assertNotEqual(h.run()['result'], 'up_to_date')

    def test_missing_foreign_profile_does_not_stop_older_search(self):
        foreign = manifest('5.3.0', 'foreign'); foreign['platform']['profile'] = 'other'
        h = Harness([foreign]); h.set_page(1, [foreign], next_page=2)
        h.set_page(2, [manifest()])
        result = h.run()
        self.assertEqual(result['result'], 'update_available')
        self.assertFalse(result['scan_complete'])
        self.assertEqual(result['error'], 'no_matching_manifest')

    def test_bad_signature_keeps_searching(self):
        h = Harness([manifest('5.3.0', 'bad'), manifest('5.2.0', 'good')])
        h.responses[('asset', 'bad', 'release-test-platform.sig')] = Response(signature(b'wrong'))
        result = h.run()
        self.assertEqual(result['candidate']['version'], '5.2.0')
        self.assertFalse(result['scan_complete'])
        self.assertEqual(result['error'], 'bad_signature')

    def test_conflicting_reissue_invalidates_candidate(self):
        a, b = manifest('5.2.0', 'a'), manifest('5.2.0', 'b')
        b['packages'][0]['sha256'] = 'b' * 64
        result = Harness([a, b]).run()
        self.assertIsNone(result['candidate'])
        self.assertEqual(result['error'], 'release_conflict')

    def test_draft_prerelease_and_empty(self):
        h = Harness(); releases = json.loads(h.responses[('list', 1)].body)
        for flag in ('draft', 'prerelease'):
            edited = deepcopy(releases); edited[0][flag] = True
            h = Harness(); h.responses[('list', 1)] = Response(dump(edited))
            self.assertEqual(h.run()['result'], 'incomplete')
            self.assertEqual(len(h.calls), 1)
        self.assertEqual(Harness([]).run()['error'], 'no_matching_manifest')

    def test_page_and_body_limits(self):
        h = Harness([])
        for page in range(1, 4): h.set_page(page, [], next_page=page + 1)
        result = h.run()
        self.assertFalse(result['scan_complete']); self.assertEqual(len(h.calls), 3)
        self.assertNotEqual(result['result'], 'up_to_date')
        h = Harness(); h.responses[('list', 1)] = Response(b' ' * (LIST_BYTES + 1))
        self.assertEqual(h.run()['error'], 'response_too_large')
        h = Harness(); h.responses[('list', 1)] = Response(dump([{}] * 11))
        self.assertEqual(h.run()['error'], 'invalid_manifest')
        h = Harness([]); h.responses[('list', 1)] = Response(b'[]', next_page=7)
        self.assertEqual(h.run()['error'], 'invalid_manifest')

    def test_deadline_before_and_after_port(self):
        h = Harness(); h.start(); h.now += DEADLINE_MS
        self.assertFalse(h.model.step()); self.assertEqual(h.calls, [])
        self.assertEqual(h.status()['error'], 'timeout')
        h = Harness()
        original = h.responses[('list', 1)]
        def slow(req):
            self.assertEqual(req.deadline_ms, 61000)
            h.now += DEADLINE_MS
            return original
        h.responses[('list', 1)] = slow
        self.assertEqual(h.run()['error'], 'timeout')
        self.assertEqual(len(h.calls), 1)

    def test_deadline_after_validation_and_clock_regression(self):
        h = Harness()
        def slow(*args):
            h.now += DEADLINE_MS
            return verify(*args)
        h.model.verifier = slow
        result = h.run()
        self.assertEqual(result['error'], 'timeout')
        self.assertIsNone(result['candidate'])
        h = Harness(); h.start(); h.now -= 1
        h.model.step()
        # Status still needs a valid monotonic clock, so inspect after recovery.
        h.now = 1000
        self.assertEqual(h.status()['error'], 'internal')

    def test_errors_and_callback_exceptions(self):
        for error in ('dns', 'tls', 'clock_untrusted', 'network'):
            h = Harness(); h.responses[('list', 1)] = Response(error=error)
            self.assertEqual(h.run()['error'], error)
        h = Harness(); h.responses[('list', 1)] = Response(b'[]', encoding='gzip')
        self.assertEqual(h.run()['error'], 'unsupported_format')
        h = Harness(); h.responses[('list', 1)] = Response(status=304)
        self.assertNotEqual(h.run()['result'], 'up_to_date')
        h = Harness()
        def broken(_): raise RuntimeError('private details')
        h.model.fetch = broken
        self.assertEqual(h.run()['error'], 'internal')

    def test_rate_limit_shared_and_background_period(self):
        h = Harness(); h.responses[('list', 1)] = Response(status=429, retry_after_ms=120000)
        h.run(); self.assertEqual(h.status()['retry_after_seconds'], 120)
        self.assertEqual(h.start()['error'], 'rate_limited')
        self.assertEqual(h.model.check('example/rover', admin=True, csrf=True)['error'], 'rate_limited')
        h.now += 120000
        self.assertTrue(h.start()['accepted'])
        h = Harness(); h.run()
        self.assertFalse(h.model.check(ID, admin=True, csrf=True, background=True)['accepted'])
        h.now += FRESH_MS
        self.assertTrue(h.model.check(ID, admin=True, csrf=True, background=True)['accepted'])

    def test_freshness_old_success_context_and_copies(self):
        h = Harness(); result = h.run(); self.assertTrue(result['fresh'])
        result['candidate']['version'] = '999.0.0'
        self.assertEqual(h.status()['candidate']['version'], '5.2.0')
        h.now += FRESH_MS - 1; self.assertTrue(h.status()['fresh'])
        h.now += 1; self.assertFalse(h.status()['fresh'])
        h.responses[('list', 1)] = Response(error='network')
        h.start(); self.assertIsNone(h.status()['result']); self.assertIsNone(h.status()['candidate'])
        old = h.drain(); self.assertEqual(old['last_success']['result'], 'update_available')
        self.assertNotIn('last_success', old['last_success'])
        ctx = local(); ctx['installed']['modbus-schoolbell']['version'] = '5.2.0'
        h.model.replace_context(ctx, KEYS)
        self.assertIsNone(h.status()['last_success']); self.assertIsNone(h.status()['candidate'])
        self.assertIsNone(Harness().status()['age_seconds'])

    def test_authorization_and_configure(self):
        h = Harness()
        self.assertEqual(h.model.check(ID)['error'], 'unauthorized')
        self.assertEqual(h.model.check(ID, admin=1, csrf=True)['error'], 'unauthorized')
        self.assertEqual(h.model.check([], admin=True, csrf=True)['error'], 'unknown_component')
        self.assertEqual(h.model.status([], authenticated=True)['error'], 'unknown_component')
        self.assertEqual(h.model.check(ID, admin=True)['error'], 'unauthorized')
        self.assertEqual(h.model.status(ID)['error'], 'unauthorized')
        self.assertEqual(h.model.check('bad', admin=True, csrf=True)['error'], 'unknown_component')
        self.assertFalse(h.model.configure(ID, False)['ok'])
        self.assertTrue(h.model.configure(ID, False, admin=True, csrf=True)['ok'])
        self.assertFalse(h.model.check(ID, admin=True, csrf=True, background=True)['accepted'])
        self.assertTrue(h.start()['accepted'])  # Manual remains available.
        self.assertFalse(h.model.configure(ID, 0, admin=True, csrf=True)['ok'])
        h.drain(); self.assertFalse(h.status()['background_checks'])

    def test_missing_ipk_asset_is_not_candidate(self):
        h = Harness(); releases = json.loads(h.responses[('list', 1)].body)
        releases[0]['assets'].pop()
        h.responses[('list', 1)] = Response(dump(releases))
        self.assertIsNone(h.run()['candidate'])


    def test_full_thirty_release_budget(self):
        h = Harness([])
        for page in range(1, 4):
            docs = [manifest('5.2.' + str(i), 'tag-' + str(i)) for i in range((page-1)*10, page*10)]
            h.set_page(page, docs, next_page=page + 1 if page < 3 else 0)
        result = h.run()
        self.assertTrue(result['scan_complete'])
        self.assertEqual(result['candidate']['version'], '5.2.29')
        self.assertEqual(len(h.calls), 63)

    def test_partial_candidate_then_network_error(self):
        h = Harness(); h.set_page(1, [manifest()], next_page=2)
        h.responses[('list', 2)] = Response(error='dns')
        result = h.run()
        self.assertEqual(result['result'], 'update_available')
        self.assertEqual(result['error'], 'dns')
        self.assertFalse(result['scan_complete'])

    def test_key_change_cancels_pending_check(self):
        h = Harness(); h.start(); h.model.step()
        calls = len(h.calls)
        h.model.replace_context(local(), {})
        self.assertFalse(h.model.step())
        self.assertEqual(len(h.calls), calls)
        self.assertIsNone(h.status()['candidate'])
        self.assertEqual(h.run()['error'], 'unknown_key')

    def test_transport_rate_limit_without_header(self):
        h = Harness(); h.responses[('list', 1)] = Response(error='rate_limited')
        h.run()
        self.assertEqual(h.start()['error'], 'rate_limited')
        self.assertEqual(h.status()['retry_after_seconds'], 60)


if __name__ == '__main__':
    unittest.main()
