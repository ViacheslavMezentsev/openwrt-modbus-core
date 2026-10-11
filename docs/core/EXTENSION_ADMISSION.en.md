# Minimal manifest and extension admission

[Русский](EXTENSION_ADMISSION.md) · [Core specification](TECHNICAL_SPECIFICATION.md)

Accepted core 1.18 section 6.7 requirements; no implementation yet.

## Extension description

package.json contains author-maintained metadata:

| Field | Condition | Purpose |
| --- | --- | --- |
| publisher, name | Required | publisher.name identity |
| version | Required | Extension version |
| displayName, description | Required | User-facing information |
| engines | Required | Core API compatibility |
| main | Executable component present | Verified entry point |
| contributes | Contributions present | Settings, events, actions, editors |
| dependencies | Dependencies present | Version constraints |
| permissions | Privileges needed | Explicit capability requests |

Missing dependencies/permissions means empty sets. contributes.configuration
references settings.schema.json when settings exist. References must resolve
within the verified bundle. Parsing JSON executes no code. Version/type semantics
and supported capabilities/permissions remain to be defined; this is not a finished
JSON Schema.

## Generated bundle manifest

The builder generates file inventory, SHA256, sizes, platform, exact dependency
versions and kernel ABI for kmod. Validate consistency with package.json and actual
content/completeness. Undeclared payload is rejected. This is separate from settings
export/template/backup metadata. Hashes do not establish publisher trust.

## Admission order

1. Bounded format parsing; identity, compatibility and trust checks.
2. Complete files and offline dependency closure; reject unknown mandatory
   fields/capabilities and incompatibilities.
3. Validate paths, types and ownership: no escape via .., absolute paths, links,
   special files or duplicate destinations; no silent overwrite of other packages
   or user data.
4. Calculate per-filesystem and RAM peaks with reserves; bound sizes, file counts
   and unpacking work. Verify author estimates and recheck resources before apply.
5. Present changes and requested privileges for review before application.
6. Stage in isolation, then activate the verified bundle with recovery available;
   prevent replacement after validation.

The initial managed format is declarative, without arbitrary extension shell hooks.
Stock dependency IPKs with hooks need a separate trust policy; declaring an arbitrary
package as a dependency must not bypass this restriction.

permissions is a declaration, not a sandbox. Enforcement and limitations must be
specified before implementation; arbitrary root code cannot be called safe merely
because its manifest passed. Validation/staging does not play audio, control hardware
or reconfigure networking. Unknown required privileges are rejected.

Question 9.2.27 tracks exact fields/types, signatures/keys, archive format, allowed
paths/types, quotas, IPK hook policy and atomic installation/recovery. TC-104–110
are planned. Visual automation scenarios remain a separate subsequent study.
