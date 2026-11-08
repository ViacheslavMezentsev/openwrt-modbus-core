# Schoolbell development archive

[https://github.com/ViacheslavMezentsev/schoolbell](https://github.com/ViacheslavMezentsev/schoolbell)

The working project has moved to its own repository. This archive is not part of package builds, package CI or Pages publication.

- [snapshot.tar.gz](snapshot.tar.gz): original tracked sources, media, native helpers, prototypes, tests, application documentation and Pages; shared integration files are retained as context.
- [manifest.json](manifest.json): original paths, modes, SHA-256 and source commit 243a7ccad6aeb2499d3efd5d0c4cef9e822d393e.
- `retired`: removed from the active tree; `integration-context`: original shared files, whose maintained counterparts remain here.

Only tracked public files were captured. No local backups, device logs, credentials, build outputs or firmware downloads are included. Historical test results retain their original scope and are not new acceptance evidence.

Inspect with `tar -tzf docs/archive/schoolbell/snapshot.tar.gz`; extract only into a separate directory. Verify using `python3 scripts/test_archive.py`.

## Migration verification

2026-11-08: `make all check-site ci-core ci-demo` passed on the host with Lua 5.1. Verified SHA-256 for all 358 archived files, absence of 309 retired files, core/demo IPKs, CI selection and stale demo cleanup. No device/data changes or Pages publication. Shared transport/I/O/release contracts and the clock-measurement skill remain in core. Historical references and retired requirement IDs remain for traceability.
