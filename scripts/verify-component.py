#!/usr/bin/env python3
"""Verify one component's source syntax and built IPK without extracting it."""
import io
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parent.parent


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def verify(component, out):
    package, name, executable = {
        'core': ('pkg', 'modbus-rtu-core', ['usr/bin/modbusd','usr/bin/modbus','etc/init.d/modbus-rtu-core','www/cgi-bin/modbus-core-status']),
        'demo': ('pkg-demo', 'modbus-demo', ['usr/bin/modbus-demo','etc/init.d/modbus-demo','www/cgi-bin/modbus-demo-status']),
        'schoolbell': ('pkg-schoolbell', 'modbus-schoolbell', []),
    }[component]
    source = ROOT/package
    controls = (source/'CONTROL/control').read_text()
    assert 'Package: '+name+'\n' in controls
    assert 'Architecture: all\n' in controls
    if component == 'core': assert 'luci-lib-jsonc' in controls
    if component == 'demo': assert 'modbus-rtu-core' in controls
    luac = shutil.which('luac5.1')
    for path in source.rglob('*'):
        if not path.is_file(): continue
        if path.suffix == '.lua' or path.read_bytes()[:40].startswith(b'#!/usr/bin/lua'):
            assert luac, 'luac5.1 is required'
            run(luac, '-p', str(path))
        elif path.read_bytes()[:40].startswith(b'#!/bin/sh'):
            run('sh', '-n', str(path))
    if component == 'core':
        for path in (ROOT/'scripts').glob('*.sh'): run('sh', '-n', str(path))
        for path in (ROOT/'scripts').glob('test_*.lua'):
            assert luac, 'luac5.1 is required'
            run(luac, '-p', str(path))
    if component == 'demo':
        assert luac, 'luac5.1 is required'
        run(luac, '-p', str(ROOT/'scripts/test_demo.lua'))
    packages = list(out.glob(name+'_*.ipk'))
    assert len(packages) == 1, 'expected one fresh '+name+' IPK'
    with tarfile.open(packages[0], 'r:gz') as outer:
        assert outer.extractfile('./debian-binary').read() == b'2.0\n'
        with tarfile.open(fileobj=io.BytesIO(outer.extractfile('./control.tar.gz').read()), mode='r:gz') as control:
            text = control.extractfile('./control').read().decode()
            assert 'Package: '+name+'\n' in text and 'Architecture: all\n' in text
            for hook in ('postinst','prerm'):
                if (source/'CONTROL'/hook).exists():
                    assert control.getmember('./'+hook).mode & 0o111, hook+' not executable'
        with tarfile.open(fileobj=io.BytesIO(outer.extractfile('./data.tar.gz').read()), mode='r:gz') as data:
            for entry in ('etc','usr','www'):
                directory = source/entry
                if not directory.exists(): continue
                for path in directory.rglob('*'):
                    if path.is_file():
                        target = './'+path.relative_to(source).as_posix()
                        assert data.extractfile(target).read() == path.read_bytes(), target+' payload mismatch'
            for path in executable:
                assert data.getmember('./'+path).mode & 0o111, path+' not executable'
    if component == 'schoolbell': run(sys.executable, str(ROOT/'scripts/verify-schoolbell.py'), str(out))
    print('[verify-component]', component, 'OK')


if __name__ == '__main__':
    verify(sys.argv[1], Path(sys.argv[2]).resolve())
