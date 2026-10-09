# Documentation

[Русский](README.md)

| Document | Purpose |
| --- | --- |
| [Technical specification](core/TECHNICAL_SPECIFICATION.md) | Current requirements, tests and open questions; Russian revision 1.5 remains a draft |
| [Development](DEVELOPMENT.en.md) | Builds, checks, signed commits and push/land workflow |
| [Validation and operation](VALIDATION.en.md) | Evidence limits, upgrade/rollback and diagnostics |
| [TODO](../TODO.md) | Remaining work and proposals needing agreement |
| [Archive](archive/README.en.md) | Completed stages and status of early planning notes |

Board and Lua-event documentation lives under [firmware](../firmware/bluepill-modbus/README.md).
Research and hardware logs remain local under `docs/research/` and `tests/manual/`.
Historical examples do not replace the current specification or DEVELOPMENT commands.

## Package documentation

- [Core](core/README.en.md): specification 1.5 and component history.
- [Demo](packages/demo/README.en.md): specification 1.0 and consumer tests.
- [Schoolbell](packages/schoolbell/README.en.md): specification 1.0, future package scope.

Each component owns RU/EN README and CHANGELOG files and a Russian specification.
The former TECHNICAL_SPECIFICATION.md is a navigation stub. New requirement/test
references include the component. When extracting a repository, move the entire
documentation folder and replace core links with a pinned contract version.
Shared history and hardware evidence are not rewritten.
