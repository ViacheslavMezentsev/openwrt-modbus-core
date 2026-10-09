# Documentation archive

[Русский](README.md) · [Current documentation](../README.en.md)

[Completed stages](completed-stages.en.md) have moved out of TODO; remaining work
is collected in [TODO](../../TODO.md). Archiving does not certify every old idea
as implemented or approve numerical claims in historical plans.

The 15 original notes previously untracked by Git were moved byte-for-byte into
local `legacy-notes/`, excluded from Git. Its `manifest.json` records original
and archive paths with SHA-256. Originals are not published with this summary;
their links and code are preserved as historical material.

| Original notes | Status |
| --- | --- |
| Steps 1–9: packages, UCI, init, libraries, cache, daemon, build, demo, hooks | Foundation implemented; current schemas and code differ from early examples |
| Step 10: validation | `make all` and local tests implemented; specification lists coverage gaps |
| Step 11: CI/CD | CI and artifacts implemented; release publication remains in TODO |
| Step 12: feed | Index generator exists; feed validation, publication and trust remain in TODO |
| Core + Modules architecture and project specification | Superseded by the current specification; trigger, module and polling extensions moved to TODO as proposals |
| Developer environment walkthrough | Superseded by DEVELOPMENT; extra Ansible/IDE integration remains a proposal |

Early FIFO examples, uninterrupted reload, resource estimates and unconditional
UCI preservation are not current guarantees. Delivery uses JSONL; recovery limits
are documented in the specification and VALIDATION. Archive commands are not
installation instructions; no feed or release is published by this cleanup.
