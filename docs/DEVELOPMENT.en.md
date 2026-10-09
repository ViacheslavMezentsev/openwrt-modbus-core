# Development and agreement

[Русский](DEVELOPMENT.md)

## Stage workflow

1. Inspect Git status and current main; use `<agent>/<task>` (Codex: `codex/`).
2. Agree on scope, requirements and acceptance criteria. Specify new behavior
   in the Russian technical specification before implementation and tests.
3. Run available checks; record skips and risks. CI is not hardware evidence.
   Update paired public docs, TODO and CHANGELOG.
4. Use English Conventional Commits with the configured GitHub signing key.
   Never disable signing; leave changes uncommitted if signing is unavailable.
5. The owner pushes. CI runs on every branch push; no new PR is required.
6. After CI succeeds for the exact branch HEAD, the owner lands: fast-forward
   main, push main, delete the work branch. If main changed and fast-forward
   is impossible, agree on integration and test the resulting HEAD again.

Historical PRs remain history, not the new workflow. Agents do not push, land,
tag or release without a separate explicit instruction.

Example owner commands (replace with the verified current branch):

```sh
git push -u origin codex/project-workflow
gh run list --branch codex/project-workflow
gh run watch <RUN_ID> --exit-status
# Match the run headSha to git rev-parse HEAD.
# Only after successful CI and with an agreed land helper:
git land codex/project-workflow
```

In the working environment, Windows Git signs commits through the WSL repository
path; the key was not copied to Linux. WSL now has a `git land` alias: fetch,
fast-forward main and the topic branch, atomically push main and delete the
remote topic branch, then delete the local topic branch. It rejects landing
main but does not check CI: the owner must verify a successful run for the exact
HEAD first. These are local settings, not distributed by the repository.
Without the helper, the owner can perform equivalent actions after CI:

```sh
git fetch origin
git switch main
git merge --ff-only origin/main
git merge --ff-only codex/project-workflow
git push origin main
# Only after successfully pushing main:
git branch -d codex/project-workflow
git push origin --delete codex/project-workflow
```

Start from a clean worktree; never discard unfinished work, delete others'
branches or force-push.

## Validation and hardware

`make all` checks packages, shell, metadata and available local tests.
Lua tests need Lua 5.1; the button test needs g++. A skipped check is not PASS.
Firmware uses `sh scripts/build-bluepill.sh` with pinned dependencies.
Script IPKs need no OpenWrt SDK, kernel compiler or router firmware rebuild.

`sh scripts/test-handlers-router.sh` runs isolated Lua regressions under router
`/tmp`, without live serial access or injecting live events. `make test-bluepill-router`
and `make test-topics-router` inspect the running system. Install/lifecycle
tests modify it: agree on impact, backups and recovery first. Preserve
kmod-usb-acm, switch_position and networking. Do not compete with modbusd for tty.

Research notes belong in local `docs/research/NN-name/`, prototypes/evidence in
`tests/manual/NN-name/`. Neither templates nor reports/logs enter Git. Accepted
contracts, code and normal tests are public, without links to private reports.

## Technical specifications

Adopt [embedded-tech-spec](https://github.com/ViacheslavMezentsev/demo-stm32-skills/tree/main/embedded-tech-spec).
SKILL.md, the template and section guidance were reviewed; the skill is not
globally installed or vendored. The [specification](TECHNICAL_SPECIFICATION.md),
revision 1.4, covers the implementation and agreed journal rejection policy, and remains a draft for agreement.
Structural validation and test references do not imply approval or hardware PASS.

- Russian-only specifications include revision/status/history, platform/scope,
  functional/interface/resource requirements, verification, traceability,
  open questions and constants/discrepancy appendices.
- One verifiable statement per permanent `X.Y.Z` ID. Removed IDs remain marked
  excluded. Origins: `[R]` recovered/confirmed behavior, `[N]` new, `[U]` clarified.
- Map every requirement to implementation or its absence and A (analysis),
  T (test), I (inspection), D (hardware) verification. Use stable `TC-NN` cases.
- Start with draft 1.0 recovered from main. Do not silently assume RTC/RS-485
  design, safe output states or real-time guarantees. A 200 ms polling setting
  currently does not guarantee a maximum end-to-end response time.
- Revisions preserve IDs and update date, history, changes, requirements,
  tests, traceability and questions. Only the owner grants approval.
- Before revising, reread the current skill and relevant `references/sections.md`.
  Inspect and run its checker from a local copy:
  `python3 <SKILL_DIR>/scripts/check_spec.py <SPEC> --strict`.
  Structural validation does not replace technical agreement.

## Changelog

Record notable changes in `[Unreleased]` in both CHANGELOG.md and CHANGELOG.en.md.
Use nonempty Added, Changed, Deprecated, Removed, Fixed, Security categories
with Russian equivalents. Describe behavior, not every commit. The owner
assigns a version/date at actual release; an IPK/Makefile version is not a
release declaration. Preserve historical stages without presenting past
checks as tests repeated today.
