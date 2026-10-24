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
for name in ("calendar", "media_codec", "media_fs", "schedule_store"):
    files["usr/share/schoolbell-editor/lua/schoolbell/" + name + ".lua"] = (
        base.parent / "lua/schoolbell" / (name + ".lua"))
files["usr/share/schoolbell-editor/lua/modbus/json_strict.lua"] = (
    repo / "pkg/usr/lib/modbus/json_strict.lua")
with tarfile.open(sys.argv[1], "w") as archive:
    for name, source in sorted(files.items()):
        data = source.read_bytes()
        entry = tarfile.TarInfo(name)
        entry.mode = 0o644
        entry.size = len(data)
        archive.addfile(entry, io.BytesIO(data))
print("Payload:", len(files), "files")
