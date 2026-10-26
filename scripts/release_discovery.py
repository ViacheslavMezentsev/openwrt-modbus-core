"""Cooperative host-only discovery model; deliberately no HTTP implementation.

step() performs at most one injected request. The port receives a deadline and a
byte cap and MUST NOT be wired to blocking/unbounded real I/O. status() never
fetches. No IPKs, installation, wall clock, filesystem, shell or router access.
"""
from copy import deepcopy
from dataclasses import dataclass
import math
from release_manifest import (Rejected, require, string, array, integer, decode,
                              compare, verified_manifest, compatible, platform_matches,
                              MANIFEST_BYTES, SIGNATURE_BYTES, LIST_BYTES)

DEADLINE_MS = 60000
FRESH_MS = 86400000
NETWORK_ERRORS = {'network', 'dns', 'tls', 'clock_untrusted', 'rate_limited',
                  'timeout', 'response_too_large', 'unsupported_format'}


@dataclass(frozen=True)
class Request:
    repository: str
    kind: str
    page: int = 0
    tag: str = ''
    asset: str = ''
    limit: int = LIST_BYTES
    deadline_ms: int = 0


@dataclass(frozen=True)
class Response:
    body: bytes = b''
    status: int = 200
    next_page: int = 0
    encoding: str = 'identity'
    error: str = None
    retry_after_ms: int = 0


class Discovery:
    def __init__(self, registry, local, keys, fetch, clock, verifier, opkg):
        self.registry, self.local, self.keys = map(deepcopy, (registry, local, keys))
        self.fetch, self.clock, self.verifier, self.opkg = fetch, clock, verifier, opkg
        self.records = {}
        self.sequence = 0
        self.active = None
        self.retry_until = {}  # GitHub repository-wide backoff, not per button.
        self.last_clock = None
        for name in registry:
            self.records[name] = dict(snapshot=self._blank(name), completed=None,
                                      last_success=None, last_completed=None,
                                      last_attempt=None, background=True)

    def _now(self):
        now = self.clock()
        require(type(now) is int and now >= 0 and
                (self.last_clock is None or now >= self.last_clock), 'internal')
        self.last_clock = now
        return now

    def _blank(self, name):
        entry = self.registry.get(name) if type(name) is str else None
        installed = self.local['installed'].get(entry['package']) if entry else None
        return dict(component=name, state='idle', operation_id=None, result=None,
                    error=None, installed_version=installed['version'] if installed else None,
                    candidate=None, scan_complete=False, fresh=False, age_seconds=None,
                    retry_after_seconds=None, background_checks=bool(entry), last_success=None)

    @staticmethod
    def _denied(code):
        return dict(accepted=False, operation_id=None, state='idle', error=code)

    def check(self, component, *, admin=False, csrf=False, background=False):
        if admin is not True or csrf is not True:
            return self._denied('unauthorized')
        if type(component) is not str or component not in self.registry:
            return self._denied('unknown_component')
        if self.active:
            if self.active['component'] == component:
                return dict(accepted=True, operation_id=self.active['id'], state='checking', error=None)
            return self._denied('busy')
        now = self._now()
        rec = self.records[component]
        repo = self.registry[component]['repository']
        if now < self.retry_until.get(repo, 0):
            return self._denied('rate_limited')
        if background and (not rec['background'] or
                           (rec['last_attempt'] is not None and now - rec['last_attempt'] < FRESH_MS)):
            return self._denied('busy')
        self.sequence += 1
        op_id = format(self.sequence, '032x')
        rec['snapshot'] = self._blank(component)
        rec['snapshot'].update(state='checking', operation_id=op_id)
        rec['completed'] = None
        rec['last_attempt'] = now
        self.active = dict(component=component, id=op_id, deadline=now + DEADLINE_MS,
                           generator=None, response=None, started=False,
                           candidate=None, problem=None, known=False, incompatible=False, incompatible_reason=None,
                           hashes={}, conflict=False)
        self.active['generator'] = self._scan()
        return dict(accepted=True, operation_id=op_id, state='checking', error=None)

    def configure(self, component, background_checks, *, admin=False, csrf=False):
        rec = self.records.get(component) if type(component) is str else None
        code = None
        if admin is not True or csrf is not True:
            code = 'unauthorized'
        elif rec is None:
            code = 'unknown_component'
        elif type(background_checks) is not bool:
            code = 'invalid_manifest'
        else:
            rec['background'] = background_checks
        return dict(ok=code is None, background_checks=rec['background'] if rec else False, error=code)

    def status(self, component, *, authenticated=False):
        # The boolean is a test authorization port, NOT a real authentication system.
        if authenticated is not True or type(component) is not str or component not in self.records:
            snap = self._blank(component)
            snap.update(state='failed', error='unauthorized' if authenticated is not True else 'unknown_component',
                        installed_version=None, background_checks=False)
            return snap
        now = self._now()
        rec = self.records[component]
        snap = deepcopy(rec['snapshot'])
        def age(s, finished):
            s['age_seconds'] = None if finished is None else (now - finished) // 1000
            s['fresh'] = bool(finished is not None and s['state'] == 'complete' and now - finished < FRESH_MS)
        age(snap, rec['completed'])
        old = deepcopy(rec['last_success'])
        if old is not None:
            age(old, rec['last_completed'])
            old.pop('last_success', None)
        snap['last_success'] = old
        snap['background_checks'] = rec['background']
        until = self.retry_until.get(self.registry[component]['repository'], 0)
        snap['retry_after_seconds'] = math.ceil((until - now) / 1000) if until > now else None
        return snap

    def replace_context(self, local, keys):
        """Trusted host operation: cancel/invalidate on package/platform/key change."""
        if local == self.local and keys == self.keys:
            return
        self.local, self.keys = deepcopy(local), deepcopy(keys)
        if self.active:
            self._finish('internal', failed=True)
        for name, rec in self.records.items():
            rec['snapshot'] = self._blank(name)
            rec['completed'] = rec['last_completed'] = rec['last_success'] = None

    def _problem(self, code):
        if self.active['problem'] is None:
            self.active['problem'] = code

    def _finish(self, code=None, failed=False):
        a = self.active
        if code:
            self._problem(code)
        rec = self.records[a['component']]
        candidate = None if a['conflict'] else a['candidate']
        error = a['problem']
        complete = error is None
        if candidate:
            result = 'update_available'
        elif failed:
            result = None
        elif error or not a['known']:
            result = 'incomplete'
            error = error or 'no_matching_manifest'
            complete = False
        else:
            result = 'incompatible' if a['incompatible'] else 'up_to_date'
            if a['incompatible']:
                error = a['incompatible_reason']
        snap = rec['snapshot']
        snap.update(state='failed' if failed and not candidate else 'complete', result=result,
                    candidate=candidate, error=error, scan_complete=complete and not failed)
        rec['completed'] = self.last_clock
        if complete and snap['state'] == 'complete':
            rec['last_success'] = deepcopy(snap)
            rec['last_completed'] = rec['completed']
        self.active = None

    def step(self):
        """Advance one fake request (or finalization); returns whether still active."""
        a = self.active
        if a is None:
            return False
        try:
            require(self._now() < a['deadline'], 'timeout')
            gen = a['generator']
            if a['started']:
                req = gen.send(a['response'])
            else:
                a['started'] = True
                req = next(gen)
            require(self._now() < a['deadline'], 'timeout')
            response = self.fetch(req)
            require(self._now() < a['deadline'], 'timeout')
            require(type(response) is Response, 'internal')
            integer(response.retry_after_ms)
            if response.retry_after_ms:
                self.retry_until[req.repository] = self._now() + response.retry_after_ms
            if response.error == 'rate_limited':
                self.retry_until[req.repository] = max(self.retry_until.get(req.repository, 0), self._now() + 60000)
            if response.error:
                require(response.error in NETWORK_ERRORS, 'internal')
                raise Rejected(response.error)
            if response.status in (429, 403):
                # Even without a valid Retry-After, refuse a rapid retry loop.
                self.retry_until[req.repository] = max(self.retry_until.get(req.repository, 0), self._now() + 60000)
                raise Rejected('rate_limited')
            if response.status == 304:
                # No cache in this model. Never mistake a bare 304 for a body.
                raise Rejected('network')
            require(response.status == 200, 'network')
            require(response.encoding == 'identity', 'unsupported_format')
            require(type(response.body) is bytes and len(response.body) <= req.limit, 'response_too_large')
            a['response'] = response
        except StopIteration:
            try:
                require(self._now() < a['deadline'], 'timeout')
                self._finish()
            except Rejected as exc:
                self._finish(exc.code, failed=True)
        except Rejected as exc:
            self._finish(exc.code, failed=True)
        except Exception:
            self._finish('internal', failed=True)
        return self.active is not None

    def _scan(self):
        a = self.active
        identity = a['component']
        entry = self.registry[identity]
        repo = entry['repository']
        profile = self.local['platform']['profile']
        stem = 'release-' + profile
        for page in range(1, 4):
            response = yield Request(repo, 'list', page=page, deadline_ms=a['deadline'])
            releases = array(decode(response.body, LIST_BYTES), 10)
            next_page = response.next_page
            require(type(next_page) is int and next_page in (0, page + 1), 'invalid_manifest')
            for release in releases:
                require(type(release) is dict)
                require(type(release.get('draft')) is bool and type(release.get('prerelease')) is bool)
                if release['draft'] or release['prerelease']:
                    continue
                tag = string(release.get('tag_name'), 256)
                # Actual GitHub objects may include additional fields; only this
                # normalized slice is consumed. Raw URLs never reach our model.
                assets = array(release.get('assets'), 130)
                names = []
                for asset in assets:
                    require(type(asset) is dict)
                    names.append(string(asset.get('name'), 192))
                if names.count(stem + '.json') != 1 or names.count(stem + '.sig') != 1:
                    # A foreign profile does not stop scanning older releases.
                    # Missing pairs are conservative uncertainty, never up-to-date.
                    self._problem('no_matching_manifest')
                    continue
                raw_response = yield Request(repo, 'asset', tag=tag, asset=stem + '.json',
                                             limit=MANIFEST_BYTES, deadline_ms=a['deadline'])
                raw = raw_response.body
                sig_response = yield Request(repo, 'asset', tag=tag, asset=stem + '.sig',
                                             limit=SIGNATURE_BYTES, deadline_ms=a['deadline'])
                try:
                    doc, digest = verified_manifest(raw, sig_response.body, repo, tag,
                                                    self.keys, self.verifier, self.opkg)
                    require(self._now() < a['deadline'], 'timeout')
                    require(doc['platform']['profile'] == profile, 'incompatible_platform')
                    platform_matches(doc['platform'], self.local)
                    for pkg in doc['packages']:
                        require(names.count(pkg['asset']) == 1)
                        key = (pkg['name'], pkg['version'], pkg['architecture'])
                        previous = a['hashes'].get(key)
                        if previous is not None and previous != pkg['sha256']:
                            a['conflict'] = True
                            raise Rejected('release_conflict')
                        a['hashes'][key] = pkg['sha256']
                    comps = [c for c in doc['components'] if c['publisher'] + '/' + c['name'] == identity]
                    if not comps:
                        continue
                    comp = comps[0]
                    require(comp['package'] == entry['package'] and comp['version_scheme'] == entry['version_scheme'])
                    version = next(p['version'] for p in doc['packages'] if p['name'] == comp['package'])
                    current = self.local['installed'].get(comp['package'])
                    require(current is not None, 'incompatible_platform')
                    a['known'] = True
                    if compare(version, current['version'], comp['version_scheme'], self.opkg) <= 0:
                        continue
                    try:
                        compatible(doc, comp, self.local, self.opkg)
                    except Rejected as exc:
                        if exc.code not in ('incompatible_platform', 'dependency_conflict'):
                            raise
                        a['incompatible'] = True
                        a['incompatible_reason'] = exc.code
                        continue
                    require(self._now() < a['deadline'], 'timeout')
                    old = a['candidate']
                    if old is None or compare(version, old['version'], comp['version_scheme'], self.opkg) > 0:
                        a['candidate'] = dict(candidate_id=digest + ':' + identity, version=version,
                                              profile=profile, manifest_sha256=digest, repository=repo,
                                              tag=tag, signature_verified=True)
                except Rejected as exc:
                    self._problem(exc.code)
            if not next_page:
                return
        self._problem('response_too_large')
