# Extension and user settings format

[Русский](EXTENSION_FORMAT.md) · [Core specification](TECHNICAL_SPECIFICATION.md)

Accepted core 1.17 profile; no implementation yet.

| Extension source file | Purpose |
| --- | --- |
| package.json | name, displayName, publisher, version, engines, main, contributes as applicable |
| settings.schema.json | Settings validation; supported schema subset remains open |
| data/ | Plans and other application documents |
| media/ | Distributed resources |

User settings.json lives separately at /etc/<package-id>/settings.json, outside
updated code. It contains values only, for example:

```json
{
  "enabled": true,
  "volume": 70,
  "activePlan": "school-week",
  "outputDevice": "school-speaker"
}
```

This illustrates a future schoolbell schema, not existing or finalized fields.
No mandatory payload wrapper or service version fields. Complex plans and media
remain separate; the package validates references.

Identity is publisher.name, explicitly mapped to the IPK name. version identifies
the extension, engines declares compatibility with the core API, main is the entry
point, contributes declares capabilities/settings. Dependency and permission
semantics need an OpenWrt-specific profile. No Node.js/npm/VSIX compatibility;
a package.json does not authorize arbitrary scripts.

Package-context API semantics:
- load() returns settings and an opaque token;
- prepareImport(source) returns a validated candidate and changes;
- save(candidate, token) saves or reports a conflict;
- export(kind) distinguishes template from backup.

Exact signatures/error codes remain open. Imported code is never executed;
installed package code owns migrations. Preparation does not activate actions;
saving and applying remain distinct under the package contract. Tokens prevent
lost concurrent edits and are not fields in settings.json.

Internal storage tracks the last successfully applied version and recovery data.
Export manifests identify the extension and producing version with explicit
kind. The package defines compatibility; version comparison alone is insufficient.
A standalone JSON needs an explicit import context and an agreed provenance policy;
never guess a migration. Independent data-format versions are introduced only
when justified, not automatically for every file.

Numerical limits, exact manifests, secrets, installation trust, archives,
fsync/recovery and atomicity remain open. Fleet templates exclude secrets and
unique bindings; backups follow a separate policy. Core 6.6 data-preservation
requirements remain in force.

Naming references: [VS Code manifest](https://code.visualstudio.com/api/references/extension-manifest)
and [settings](https://code.visualstudio.com/docs/configure/settings).
We borrow the separation between extension metadata and user values.

Specification 1.18 defines minimal package.json, generated bundle metadata and content/compatibility/trust/resource admission. Declarative installation excludes arbitrary extension hooks; trusted IPKs and runtime permissions need separate policies. TC-104–110 are planned; no implementation.

[Extension admission](EXTENSION_ADMISSION.en.md)
