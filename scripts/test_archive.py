#!/usr/bin/env python3
"""Validate the historical snapshot without extracting or executing its contents."""
from pathlib import Path, PurePosixPath
import hashlib, json, tarfile, subprocess
root=Path(__file__).resolve().parent.parent
folder=root/'docs/archive/schoolbell'
manifest=json.loads((folder/'manifest.json').read_text())
archive=folder/'snapshot.tar.gz'
subprocess.run(['git','ls-files','--error-unmatch',str(archive.relative_to(root))],cwd=root,check=True,stdout=subprocess.DEVNULL)
assert hashlib.sha256(archive.read_bytes()).hexdigest()==manifest['archive_sha256']
records={x['path']:x for x in manifest['files']}
with tarfile.open(archive) as tar:
    assert len(tar.getmembers())==len(records)
    assert set(tar.getnames())==set(records)
    for entry in tar:
        path=PurePosixPath(entry.name); assert not path.is_absolute() and '..' not in path.parts
        assert entry.isfile()
        row=records[entry.name]; data=tar.extractfile(entry).read()
        assert len(data)==row['size'] and entry.mode==row['mode']
        assert hashlib.sha256(data).hexdigest()==row['sha256']
        if row['role']=='retired': assert not (root/entry.name).is_file(), entry.name
print('[archive] verified',len(records),'files; retired sources absent')
