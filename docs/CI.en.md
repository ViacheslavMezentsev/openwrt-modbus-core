# Component CI checks

[Русский](CI.md) · [Development](DEVELOPMENT.en.md)

One `CI - components` workflow runs on pushes to every branch and on manual dispatch.
The final job is `ci-gate`. Before land, verify the successful run belongs to the
exact HEAD; one green component is insufficient. Push/land remain owner actions.
Existing GitHub required-check settings are not changed automatically.

## Job selection

| Changes | Jobs in addition to always-run docs/ci-gate |
| --- | --- |
| README/CHANGELOG and ordinary Markdown guides | No component jobs |
| Core code, firmware, core contracts, AGENTS.md | core + demo + schoolbell |
| Demo code/tests, specification and other contract documents | demo |
| Schoolbell code/media/verifier, specification and other contract documents | schoolbell |
| Makefile, shared scripts, CI, dependencies, unknown paths | All components |

Component README/CHANGELOG files are overviews; other files under `docs/core/`
and `docs/packages/<package>/` are conservatively treated as contracts. Core
changes test consumers without asserting hardware compatibility. Schoolbell is
still media-only: its job verifies MP3/manifest and package contents, not a working
bell. Demo tests use current core modules. Firmware changes run available core
regressions; Arduino compilation remains separate, as do hardware tests.

Paths come from local Git diff between push before and current SHA with rename
detection disabled, covering both sides of moves and deleted files. First branch
pushes, manual dispatch and unavailable history run everything. Later ordinary
docs-only pushes skip component builds. Mixed changes select the union of jobs.
There is no workflow-level paths-ignore that could suppress the final status.

## Checks

- `docs`: local Markdown inline/reference-definition targets and heading anchors,
  strict validation of all three specifications, selection/gate regression tests.
- `core`: C++ button test, core Lua tests/syntax, IPK build and verification.
- `demo`: actual demo-loop Lua test, syntax, its IPK build and verification.
- `schoolbell`: preview build, pinned media hashes and exact IPK contents.
- `ci-gate`: requires changes/docs and every selected component to succeed.
  Failure, cancellation or unexpected skips fail the gate. Only explicitly
  unselected jobs may be skipped; missing/invalid selection outputs fail closed.

Separate `core-ipk`, `demo-ipk` and `schoolbell-ipk` artifacts contain packages
and checksums. Docs-only pushes do not publish new IPKs. CI performs no router
installations, playback, serial access or hardware reboots.

## Local reproduction

```sh
make check-docs check-ci
make ci-core
make ci-demo
make ci-schoolbell
make all
```

Requires Python 3.8+, Lua 5.1/luac5.1, g++ and standard make/tar/sha256sum tools.
Core/demo component targets fail if mandatory Lua is unavailable; core also
requires a C++ compiler. A skipped mandatory test is not PASS. Outputs are isolated
in `out/ci-core`, `out/ci-demo`, `out/ci-schoolbell`. `make all` retains the full
previous run and additionally checks documentation and CI policy.

The specification validator is vendored unchanged under
`scripts/vendor/embedded-tech-spec/`, with pinned source commit, SHA256 manifest
and MIT LICENSE. Updates explicitly change the copy/manifest and revalidate all
specifications; CI never fetches it from a moving branch. Markdown checks do not
request external URLs and are not a complete Markdown/HTML renderer.

After Windows Git operations also inspect `git status` in WSL: Windows
core.filemode=false can hide changed executable bits. Keep WSL mode checks enabled.

See GitHub Actions [job conditions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idif)
and [needs context](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#needs-context).
Selection/gate regressions live in scripts/test_ci.py.
