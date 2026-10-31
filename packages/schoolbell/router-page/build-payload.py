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
for media in range(5):
    files["usr/share/schoolbell-sound-test/"+str(media)+".mp3"] = base.parent / ("media/"+str(media)+".mp3")
for name in ("plan_export_bundle", "plan_import", "plan_admission", "automatic_status", "system_metrics", "queue_metrics", "clock_set", "clock_commands", "clock_mailbox", "clock_policy", "clock_gate", "clock_trust", "clock_reference", "clock_reference_store", "clock_system", "backup", "backup_codec", "mp3", "media_manager", "media_library", "calendar", "media_codec", "media_fs", "schedule_store", "journal", "timezone", "controls", "automatic", "automatic_store"):
    files["usr/share/schoolbell-editor/lua/schoolbell/" + name + ".lua"] = (
        base.parent / "lua/schoolbell" / (name + ".lua"))
for name in ('codec','preview','export'):
    files['usr/share/schoolbell-editor/lua/schoolbell/plan_'+name+'.lua'] = base.parent / ('portable-plan/'+name+'.lua')
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
    dependency=b'{"time_control":{"package":"modbus-schoolbell-clock","version":"1.0.0","architecture":"mipsel_24kc","lua":"5.1","required_when_enforced":true}}\n'
    info=tarfile.TarInfo('usr/share/schoolbell-editor/dependencies.json');info.mode=0o644;info.size=len(dependency)
    archive.addfile(info,io.BytesIO(dependency))
    for name, source in sorted(files.items()):
        data = source.read_bytes()
        entry = tarfile.TarInfo(name)
        entry.mode = 0o755 if name.startswith(('etc/init.d/', 'usr/sbin/')) else 0o644
        entry.size = len(data)
        archive.addfile(entry, io.BytesIO(data))
print("Payload:", len(files) + 1, "files")
