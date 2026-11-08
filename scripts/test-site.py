#!/usr/bin/env python3
"""Ensure a rebuild removes stale application assets and leaves no local dead links."""
from pathlib import Path
import subprocess, tempfile, re
from urllib.parse import urlsplit
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory() as d:
    out=Path(d)/'site'; (out/'schoolbell/assets').mkdir(parents=True)
    (out/'schoolbell/assets/old.js').write_text('obsolete application')
    subprocess.run(['python3',str(root/'scripts/build-site.py'),str(out)],check=True)
    assert not list(out.rglob('*.js')) and not list(out.rglob('*.mp3'))
    for p in out.rglob('*.html'):
        text=p.read_text(); assert 'https://github.com/ViacheslavMezentsev/schoolbell' in text
        for link in re.findall(r'(?:href|src)="([^"]+)"',text):
            u=urlsplit(link)
            if not u.scheme: assert (p.parent/u.path).exists(), (p,link)
print('[site] migration routes and stale-asset cleanup OK')
