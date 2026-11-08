#!/usr/bin/env python3
"""Build the core landing page; retired application routes contain links only."""
from pathlib import Path
import shutil, sys
root = Path(__file__).resolve().parent.parent
out = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'out/site'
if out == root or root in out.parents and root/'out' not in out.parents:
    raise SystemExit('output must not overwrite source files')
out.mkdir(parents=True, exist_ok=True)
# Remove stale generated application assets, never source files.
for child in out.iterdir():
    if child.is_dir() and not child.is_symlink(): shutil.rmtree(child)
    else: child.unlink()
for name in ('index.html','index.en.html','style.css'):
    shutil.copyfile(root/'site'/name, out/name)
(out/'.nojekyll').write_text('')
notice = '<!doctype html><meta charset="utf-8"><title>Schoolbell has moved</title><p>Школьник переехал / Schoolbell has moved:</p><a href="https://github.com/ViacheslavMezentsev/schoolbell">Schoolbell repository</a>\n'
for name in ('schoolbell/index.html','schoolbell/guide.html','schoolbell/guide.en.html','schoolbell/training.html','schoolbell/training.en.html','devices/index.html','devices/index.en.html','devices/tl-mr3020-eu-v3.30.html','devices/tl-mr3020-eu-v3.30.en.html'):
    dest=out/name; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_text(notice)
print('[site] core landing and migration links built')
