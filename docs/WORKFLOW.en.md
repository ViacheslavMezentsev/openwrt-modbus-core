# Collaborative workflow

[Русский](WORKFLOW.md) · [Development](DEVELOPMENT.en.md) · [CI](CI.en.md)

This guide records the recurring owner/Codex cycle, from a small agreed stage to
device acceptance. [AGENTS.md](../AGENTS.md) defines repository rules;
DEVELOPMENT contains build and integration details.

## Responsibilities

The owner chooses scope, accepts behavior/results, authorizes device effects,
and performs push, land, Pages publication, tags and releases. Codex inspects the
baseline, prepares the branch, requirements/code/tests, documentation and signed
commit, performs authorized checks, prepares backups/rollback and reports evidence.
No new PRs are used. Implementation permission does not authorize installation,
sound, automatic bells or clock changes. Existing authorization remains valid
within its scope; changed effects need separate agreement.

## 1. Agree a stage and establish the baseline

1. Read AGENTS, README, TODO, Unreleased and the affected component documents.
2. Check status, branch, local commits and origin/main after `git fetch origin`.
   Verify the owner's “merged” message against Git.
3. Never discard or hide someone else's edits to switch branches; investigate
   differences rather than force-resetting them.
4. Agree a small verifiable outcome and boundaries: requirements or runtime,
   host or device, permission for sound and automatic bells.
5. Create `codex/<task>` from current clean main, or continue an agreed unfinished
   branch. One completed stage normally corresponds to one branch.

New behavior first gets requirements in its owning component specification.
Core and packages own separate contracts. Unknowns remain open questions;
requirements-only branches do not constitute implementation or installation.

## 2. Implement and test on the host

Reproduce the issue or establish acceptance criteria, then change code and add
meaningful tests. Cover affected boundaries, faults, concurrency, lost responses
and data preservation. Diagnose causes rather than repeating manual attempts.

| Change | Checks |
| --- | --- |
| Documentation only | `make check-docs`, diff review and factual consistency |
| Runtime, packaging or shared mechanisms | Relevant regressions and `make all` with required dependencies including Lua 5.1 |
| Shkolnik UI | UI regressions, `make check-site`, visual inspection and shared Pages source synchronization |
| Firmware | Relevant tests and `sh scripts/build-bluepill.sh`; flashing separately authorized |

Skipped tests are not PASS. Distinguish model tests, real code on the host,
isolated target experiments and installed operation. Rerun affected checks after
fixes; CI does not replace hardware evidence.

Update TODO, the owning component's Unreleased, affected requirements and paired
RU/EN public docs. Package versions distinguish installed builds. Documentation
alone needs no IPK version bump. Shkolnik uses major.minor.patch; small package
changes increment patch.

## 3. Sign and hand over

Review the diff and `git diff --check`; stage named files, never all of docs.
Keep research, backups, hardware logs and downloaded builds out of Git; do not
force-add them. Use an English Conventional Commit signed by the configured key.
In this environment Windows Git signs through the WSL repository UNC path;
do not copy the key into WSL or disable signing on failure.

Verify the signature and clean status with WSL Git too, including modes and line
endings. Report branch/SHA, changes, checks, skips, limitations and next step.
Provide the exact branch name in owner commands, for example:

```sh
git push -u origin codex/example-stage
gh run list --branch codex/example-stage
gh run watch <RUN_ID> --exit-status
```

Match the run's headSha to the pushed SHA and require successful aggregate
ci-gate. A previous commit or individual green job is insufficient. Only then:

```sh
git land codex/example-stage
```

Land is a local helper, not built-in Git, and does not check CI itself. See
DEVELOPMENT for its operations/manual equivalent. If main changed and cannot
fast-forward, integrate separately and recheck/re-run CI for the new HEAD.
No force-push or bypassing checks.

## 4. Install and check the device

Normal sequence: host checks → signed commit → owner push/CI/land → separate
installation authorization → backup → installation → acceptance.
Explicitly agreed target testing may occur **before push** on the current branch.
Record exact SHA/build contents and hold push until acceptance; retest and commit
any fixes before handover.

Before installation, inspect installed/proposed versions and contents, free space
and automatic execution state; version numbers alone are insufficient. Save a
fresh local backup of settings, plans, user media and required metadata; verify
readability/contents. Retain the previous suitable IPK/dependencies, checksums and
rollback commands. Prepared rollback is different from exercised rollback.
Record the experiment's goal, conditions, allowed actions and expected outcome.

Access the device through WSL Ubuntu-20.04 and SSH openwrt; build on the host,
not the device. Verify installed payload, versions, services, preserved data and
agreed system guards. Do not implicitly change bells, sound, power/USB, network,
firmware, clocks or NTP for testing. Restore the agreed final state after permitted
test activation, normally bells disabled. Never open serial alongside the core.
Remove temporary IPKs and owned unnecessary caches after checks, not user data.

## 5. Owner UI acceptance

Codex performs available checks first, then provides short UI steps with an
observable result. Use one step at a time if needed. Warn about unsaved edits
before suggesting Ctrl+F5; do not lose edits to refresh the page.
Owner feedback confirms the observed appearance, persistence or audible sound,
not all device invariants. Preserve original failures and evidence. Do not ask
for blind retries of mutations whose previous outcome is unknown.

Synchronize Pages sources, build and inspect locally; the owner publishes them.
Source synchronization and public deployment are separate statuses. Demo tests
are not hardware acceptance.

## 6. Close and repeat

Keep target reports under local docs/research/NN-name, experiment data under
tests/manual/NN-name and prepend local HISTORY. Retain original FAIL/ERROR
records. Public docs receive accepted conclusions without hardware identifiers
or links to unavailable local reports.

The final handover identifies implemented and owner-confirmed behavior, host and
target evidence and missing checks, installed version/bell state/data preservation,
branch/SHA and commands (or push held), and the next small TODO stage.
After “merged”, inspect Git again. A short successful check is not unattended
service acceptance; use the separate [Shkolnik acceptance programme](packages/schoolbell/ACCEPTANCE.en.md).
