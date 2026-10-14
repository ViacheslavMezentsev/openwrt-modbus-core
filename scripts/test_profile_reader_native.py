"""Optional integration with real Lua 5.1/nixio. Run as root in Linux host only.
Set LUA_BIN, LUA_PATH and LUA_CPATH to the host-built nixio environment.
No router access; temporary fixtures live under /root (never writable /tmp).
"""
import os
from pathlib import Path
import subprocess
import tempfile

def main():
    if os.geteuid() != 0:
        raise SystemExit("native fixture test requires host root")
    with tempfile.TemporaryDirectory(prefix="omc-profile-reader-", dir="/root") as name:
        base = Path(name)
        payload = b'{"id":"p","read_ranges":[{"function":3,"start":0,"count":1}]}'
        for kind in ("good", "exact", "oversize", "symlink", "fifo", "hardlink",
                     "writable", "foreign", "directory", "missing", "weakdir",
                     "racereg", "racesymlink", "raceread"):
            directory = base / kind
            directory.mkdir()
            target = directory / "p.json"
            if kind == "missing":
                continue
            if kind == "directory":
                target.mkdir()
            elif kind == "symlink":
                target.symlink_to(base / "good" / "p.json")
            elif kind == "fifo":
                os.mkfifo(target)
            elif kind == "hardlink":
                source = directory / "other.json"
                source.write_bytes(payload)
                os.link(source, target)
            else:
                target.write_bytes(b" " * 16384 if kind == "exact" else
                                   b" " * 16385 if kind == "oversize" else payload)
                target.chmod(0o666 if kind == "writable" else 0o644)
                if kind == "foreign":
                    os.chown(target, 65534, 65534)
                if kind == "weakdir":
                    directory.chmod(0o777)
        for kind in ("racereg", "racesymlink", "raceread"):
            replacement = base / kind / "replacement"
            if kind == "racesymlink":
                replacement.symlink_to(base / "good" / "p.json")
            else:
                replacement.write_bytes(payload)
                replacement.chmod(0o644)
        (base / "linkdir").symlink_to(base / "good", target_is_directory=True)
        subprocess.run([os.environ.get("LUA_BIN", "lua5.1"),
                        "scripts/test_profile_reader_native.lua", str(base)],
                       check=True, timeout=20)

if __name__ == "__main__":
    main()
