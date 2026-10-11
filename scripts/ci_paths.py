#!/usr/bin/env python3
"""Conservative component selection. Unknown/missing Git history means full CI."""
import json
import os
from pathlib import Path
import re
import subprocess

COMPONENTS = ('core', 'demo', 'schoolbell')


def select(paths):
    selected = set()
    if paths is None:
        return dict.fromkeys(COMPONENTS, True)
    for path in paths:
        overview = path.rsplit('/', 1)[-1] in ('README.md', 'README.en.md', 'CHANGELOG.md', 'CHANGELOG.en.md')
        # Contracts are code dependencies even when they are Markdown.
        if path in ('AGENTS.md', 'docs/TECHNICAL_SPECIFICATION.md') or path.startswith('.github/'):
            selected.update(COMPONENTS)
        elif path.startswith('docs/core/') and not overview:
            selected.update(COMPONENTS)
        elif path.startswith('docs/packages/demo/') and not overview:
            selected.add('demo')
        elif path.startswith('docs/packages/schoolbell/') and not overview:
            selected.add('schoolbell')
        elif path.endswith('.md') and (path.startswith(('docs/', 'firmware/', 'packages/')) or '/' not in path):
            pass
        elif path.startswith('pkg-demo/') or path == 'scripts/test_demo.lua':
            selected.add('demo')
        elif path.startswith(('pkg-schoolbell/', 'packages/schoolbell/')) or path == 'scripts/verify-schoolbell.py':
            selected.add('schoolbell')
        else:
            # Core, firmware, build/CI scripts and every unclassified path.
            selected.update(COMPONENTS)
    return {name: name in selected for name in COMPONENTS}


def changed_paths(before, head, cwd=None):
    if not re.fullmatch(r'[0-9a-fA-F]{40}', before or '') or set(before) == {'0'}:
        return None
    if not re.fullmatch(r'[0-9a-fA-F]{40}', head or ''):
        return None
    try:
        subprocess.run(['git', 'cat-file', '-e', before + '^{commit}'], cwd=cwd,
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        data = subprocess.check_output(['git', 'diff', '--name-only', '-z', '--no-renames',
                                        before, head, '--'], cwd=cwd)
        return [x.decode('utf-8', 'surrogateescape') for x in data.split(b'\0') if x]
    except subprocess.CalledProcessError:
        return None


def main():
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    paths = changed_paths(event.get('before'), os.environ.get('GITHUB_SHA'))
    plan = select(paths)
    print(json.dumps({'full_fallback': paths is None, 'paths': paths, 'jobs': plan}, ensure_ascii=True))
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        for name, enabled in plan.items():
            output.write(name + '=' + str(enabled).lower() + '\n')


if __name__ == '__main__':
    main()
