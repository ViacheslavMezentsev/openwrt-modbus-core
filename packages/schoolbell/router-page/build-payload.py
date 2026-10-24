#!/usr/bin/env python3
"""Build the engineering LuCI payload; no installation or dependency downloads."""
import io
import pathlib
import sys
import tarfile

base = pathlib.Path(__file__).resolve().parent
repo = base.parents[2]
files = {str(p.relative_to(base / "root")): p
         for p in (base / "root").rglob("*") if p.is_file()}
files["usr/share/schoolbell-sound-test/test.mp3"] = base.parent / "media/test.mp3"
for name in ("calendar", "media_codec", "media_fs", "schedule_store", "journal", "timezone"):
    files["usr/share/schoolbell-editor/lua/schoolbell/" + name + ".lua"] = (
        base.parent / "lua/schoolbell" / (name + ".lua"))
files["usr/share/schoolbell-editor/lua/modbus/json_strict.lua"] = (
    repo / "pkg/usr/lib/modbus/json_strict.lua")
version = next(line.split(': ', 1)[1] for line in
               (repo / 'pkg-schoolbell/CONTROL/control').read_text().splitlines()
               if line.startswith('Version: '))
import re
assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version), 'expected major.minor.patch'
with tarfile.open(sys.argv[1], "w") as archive:
    data = (version + '\n').encode()
    entry = tarfile.TarInfo('usr/share/schoolbell-editor/VERSION')
    entry.mode = 0o644
    entry.size = len(data)
    archive.addfile(entry, io.BytesIO(data))
    for name, source in sorted(files.items()):
        data = source.read_bytes()
        entry = tarfile.TarInfo(name)
        entry.mode = 0o644
        entry.size = len(data)
        archive.addfile(entry, io.BytesIO(data))
print("Payload:", len(files) + 1, "files")
