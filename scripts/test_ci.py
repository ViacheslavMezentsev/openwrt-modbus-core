#!/usr/bin/env python3
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from ci_paths import select, changed_paths
from ci_gate import errors
from check_docs import link_errors, verify_vendor


class SelectionTests(unittest.TestCase):
    def chosen(self, paths):
        return {k for k, v in select(paths).items() if v}

    def test_docs_only(self):
        for path in ('README.md', 'docs/DEVELOPMENT.md', 'docs/packages/demo/README.md',
                     'packages/schoolbell/media/README.en.md'):
            self.assertEqual(self.chosen([path]), set())

    def test_packages(self):
        for path in ('pkg-demo/usr/bin/modbus-demo', 'scripts/test_demo.lua',
                     'docs/packages/demo/TECHNICAL_SPECIFICATION.md', 'docs/packages/demo/EVENT_API.md'):
            self.assertEqual(self.chosen([path]), {'demo'})
        for path in ('pkg-schoolbell/CONTROL/control', 'packages/schoolbell/media/0.mp3',
                     'scripts/verify-schoolbell.py', 'scripts/test-schoolbell.sh',
                     'packages/schoolbell/lua/schoolbell/calendar.lua',
                     'packages/schoolbell/tests/test_calendar.lua',
                     'docs/packages/schoolbell/TECHNICAL_SPECIFICATION.md'):
            self.assertEqual(self.chosen([path]), {'schoolbell'})

    def test_shared_and_contracts(self):
        for path in ('pkg/usr/lib/modbus/json.lua', 'Makefile', '.github/workflows/ci.yml',
                     'scripts/ci_paths.py', 'scripts/run-tests.sh', 'AGENTS.md',
                     'docs/core/EVENT_API.md', 'docs/core/new-contract.md', 'docs/core/TECHNICAL_SPECIFICATION.md',
                     'docs/TECHNICAL_SPECIFICATION.md', 'new-unknown/file', 'pkg/README.md'):
            self.assertEqual(self.chosen([path]), {'core', 'demo', 'schoolbell'}, path)

    def test_union_fallback_empty(self):
        self.assertEqual(self.chosen(['pkg-demo/x', 'pkg-schoolbell/x']), {'demo', 'schoolbell'})
        self.assertEqual(self.chosen(None), {'core', 'demo', 'schoolbell'})
        self.assertEqual(self.chosen([]), set())
        self.assertIsNone(changed_paths('0'*40, 'a'*40))
        self.assertIsNone(changed_paths('--bad', 'a'*40))

    def test_git_rename_delete_and_missing_base(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=Fixture',
                    '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false',
                    *args], cwd=root, stderr=subprocess.DEVNULL).decode().strip()
            git('init'); (root/'pkg-demo').mkdir(); (root/'pkg-demo/old').write_text('old')
            (root/'pkg-demo/deleted').write_text('deleted')
            git('add', '.'); git('commit', '-m', 'before'); before = git('rev-parse', 'HEAD')
            (root/'pkg-schoolbell').mkdir(); (root/'pkg-demo/old').rename(root/'pkg-schoolbell/new')
            (root/'pkg-demo/deleted').unlink(); git('add', '-A'); git('commit', '-m', 'after')
            head = git('rev-parse', 'HEAD')
            paths = changed_paths(before, head, root)
            self.assertEqual(set(paths), {'pkg-demo/old', 'pkg-demo/deleted', 'pkg-schoolbell/new'})
            self.assertEqual(self.chosen(paths), {'demo', 'schoolbell'})
            self.assertIsNone(changed_paths('a'*40, head, root))


class GateTests(unittest.TestCase):
    def needs(self):
        return {'changes': {'result': 'success', 'outputs': {'core':'true','demo':'false','schoolbell':'false'}},
                'docs': {'result':'success'}, 'core': {'result':'success'},
                'demo': {'result':'skipped'}, 'schoolbell': {'result':'skipped'}}

    def test_success_and_selected_failure(self):
        good = self.needs(); self.assertEqual(errors(good), [])
        for result in ('skipped', 'failure', 'cancelled', None):
            n = copy.deepcopy(good); n['core']['result'] = result
            self.assertTrue(errors(n))

    def test_mandatory_and_invalid_outputs(self):
        for job in ('changes', 'docs'):
            n = self.needs(); n[job]['result'] = 'skipped'; self.assertTrue(errors(n))
        for selected in ('', None, 'TRUE'):
            n = self.needs(); n['changes']['outputs']['core'] = selected; self.assertTrue(errors(n))
        self.assertTrue(errors({}))

    def test_unselected_failure_not_hidden(self):
        for result in ('failure', 'cancelled', None):
            n = self.needs(); n['demo']['result'] = result; self.assertTrue(errors(n))


class DocumentationTests(unittest.TestCase):
    def test_vendor_integrity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'check_spec.py').write_bytes(b'validator')
            (root/'LICENSE').write_bytes(b'license')
            (root/'manifest.json').write_text(json.dumps({
                'sha256': hashlib.sha256(b'validator').hexdigest(),
                'license_sha256': hashlib.sha256(b'license').hexdigest()}))
            verify_vendor(root)
            (root/'check_spec.py').write_bytes(b'changed')
            with self.assertRaises(AssertionError): verify_vendor(root)


    def test_local_links_fragments_and_code_examples(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); source = root/'README.md'; dest = root/'other.md'
            dest.write_text('# Target\n'); source.write_text('')
            self.assertEqual(link_errors(source, '[ok](other.md#target)', root), [])
            self.assertTrue(link_errors(source, '[bad](other.md#absent)', root))
            self.assertTrue(link_errors(source, '[bad](missing.md)', root))
            self.assertTrue(link_errors(source, '[bad](../outside.md)', root))
            self.assertEqual(link_errors(source, '```md\n[example](missing.md)\n```', root), [])
            self.assertEqual(link_errors(source, '[web](https://example.invalid/no-network)', root), [])


if __name__ == '__main__':
    unittest.main()
