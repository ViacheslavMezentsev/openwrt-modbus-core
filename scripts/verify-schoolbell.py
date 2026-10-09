#!/usr/bin/env python3
"""Verify pinned media and the media-only schoolbell preview IPK (no extraction)."""
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile

root = Path(__file__).resolve().parent.parent
media = root / 'packages/schoolbell/media'
manifest = json.loads((media / 'manifest.json').read_text())
for item in manifest['files']:
    data = (media / item['path']).read_bytes()
    assert len(data) == item['bytes'], item['path'] + ': size mismatch'
    assert hashlib.sha256(data).hexdigest() == item['sha256'], item['path'] + ': SHA256 mismatch'
sample = (media / 'test.mp3').read_bytes()
source_sample = root / 'pkg-schoolbell/usr/share/modbus-schoolbell/melodies/test.mp3'
assert source_sample.read_bytes() == sample, 'package source differs from pinned sample'
out = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'out'
packages = list(out.glob('modbus-schoolbell_*.ipk'))
assert packages, 'schoolbell IPK missing'
for package in packages:
    with tarfile.open(package, 'r:gz') as outer:
        with tarfile.open(fileobj=io.BytesIO(outer.extractfile('./control.tar.gz').read()), mode='r:gz') as control:
            files = {(m.name[2:] if m.name.startswith('./') else m.name) for m in control if not m.isdir()}
            assert files == {'control'}, 'unexpected lifecycle hook in preview'
            text = control.extractfile('./control').read().decode()
            assert 'Package: modbus-schoolbell\n' in text
        with tarfile.open(fileobj=io.BytesIO(outer.extractfile('./data.tar.gz').read()), mode='r:gz') as data:
            files = {(m.name[2:] if m.name.startswith('./') else m.name) for m in data if not m.isdir()}
            expected = {'usr/share/modbus-schoolbell/NOTICE', 'usr/share/modbus-schoolbell/melodies/test.mp3'}
            assert files == expected, 'unexpected preview payload (service/config/extra media)'
            assert data.extractfile('./usr/share/modbus-schoolbell/melodies/test.mp3').read() == sample
    print('[schoolbell] pinned media and preview payload OK:', package.name)
