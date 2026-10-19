#!/usr/bin/env python3
"""Offline checks for tracked Markdown links and independently versioned specs."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent


def prose(text):
    # Code examples are not live links/headings.
    return re.sub(r'(?ms)^(```|~~~).*?^\1[^\n]*$', '', text)


def anchors(text):
    result, used = set(), {}
    for line in prose(text).splitlines():
        match = re.match(r'^#{1,6}\s+(.+?)\s*#*$', line)
        if match:
            slug = re.sub(r'[^\w\- ]', '', match[1].lower()).replace(' ', '-')
            number = used.get(slug, 0); used[slug] = number + 1
            result.add(slug + ('-' + str(number) if number else ''))
    result.update(re.findall(r'<a\s+(?:name|id)=["\']([^"\']+)', text))
    return result


def link_errors(path, text, root=ROOT):
    errors = []
    clean = prose(text)
    links = re.findall(r'!?\[[^\]\n]*\]\(([^)\n]+)\)', clean)
    links += re.findall(r'(?m)^\s*\[[^\]]+\]:\s*(\S+)', clean)
    for raw in links:
        target = raw.strip().split(' "', 1)[0].strip('<>')
        url = urlsplit(target)
        if url.scheme or url.netloc:
            continue  # No online link checks; no network dependency in docs CI.
        dest = (path.parent / unquote(url.path)).resolve() if url.path else path.resolve()
        try:
            dest.relative_to(root.resolve())
        except ValueError:
            errors.append(str(path) + ': link leaves repository: ' + target); continue
        if not dest.exists():
            errors.append(str(path) + ': missing link: ' + target)
        elif url.fragment and dest.suffix == '.md':
            if unquote(url.fragment) not in anchors(dest.read_text(encoding='utf-8')):
                errors.append(str(path) + ': missing anchor: ' + target)
    return errors


def verify_vendor(vendor):
    manifest = json.loads((vendor/'manifest.json').read_text())
    for name, key in [('check_spec.py','sha256'), ('LICENSE','license_sha256')]:
        assert hashlib.sha256((vendor/name).read_bytes()).hexdigest() == manifest[key], name + ': vendor hash mismatch'


def main():
    vendor = ROOT / 'scripts/vendor/embedded-tech-spec'
    verify_vendor(vendor)
    tracked = subprocess.check_output(['git','ls-files','-z','--','*.md'], cwd=ROOT).split(b'\0')
    errors = []
    for item in tracked:
        if item:
            path = ROOT / item.decode()
            if not path.exists():
                errors.append(str(path) + ': tracked file missing'); continue
            errors += link_errors(path, path.read_text(encoding='utf-8'))
    for spec in ('docs/core/TECHNICAL_SPECIFICATION.md',
                 'docs/packages/demo/TECHNICAL_SPECIFICATION.md',
                 'docs/packages/schoolbell/TECHNICAL_SPECIFICATION.md',
                 'docs/packages/rover/TECHNICAL_SPECIFICATION.md'):
        result = subprocess.run([sys.executable, str(vendor/'check_spec.py'), str(ROOT/spec), '--strict'])
        if result.returncode: errors.append(spec + ': specification check failed')
    if errors:
        raise SystemExit('\n'.join(errors))
    print('[docs] tracked Markdown links/anchors and four specifications OK; vendor hashes verified')


if __name__ == '__main__':
    main()
