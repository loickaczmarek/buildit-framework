# fix/audit — branch summary

## Status
shipped (all tasks committed on `fix/audit`, not yet merged into `main`)

## Branch
fix/audit

## Goal
Fix the findings of two audits of the buildit skills:
1. **24-11-2026 audit** (35 findings: 8 High, 15 Medium, 12 Low), split into 13 tasks via `/buildit-plan` (4 epics) and run sequentially with `/buildit-feature-run`.
2. **25-11-2026 audit** of this branch's own changes (11 regressions introduced by the first round), then follow-up simplifications.

This file replaces the 17 per-task tracking files that used to live in `.scratch/done/`. They are still in git history (last present at `0907a9c`); recover one with `git show 0907a9c:.scratch/done/<file>`.

## Outcome
- 18 commits (`141d0ba..0907a9c`), 56 files changed (+3978 / −576).
- Test suite: 26 test files, **1355 passed, 0 failed** (`bash tests/run-all.sh`, 25-11-2026, after the cleanup below). Baseline at the second audit was 1153.
- 1 NO-GO cycle across the whole branch (`task-ship-closing-commit`: a duplicated README section, which led to the heading-uniqueness check).

## Round 1 — 24-11-2026 audit (13 tasks)

### Epic 1: Worktree and ship correctness
| Task | Commit | What changed |
|---|---|---|
| merge-readiness-branch-key | `8d4dc58` | Start writes `## Branch` once (from `buildit-worktree`'s `Branch:` line or the checked-out branch, stop on detached HEAD). The Merge readiness row is keyed by that branch and written only after start succeeds. Ship skips its own row in the overlap check. |
| ship-closing-commit | `3137082` | Ship runs cleanup → retro/config → explicit-path staging → commit → worktree removal. `WORKTREE_PATH` is read once at step 0. Run takes `SHIP_REF` from `## Branch`. README de-duplicated, heading uniqueness tested. |
| worktree-working-directory | `1de9ffe` | Build/validate run tests with the worktree as working directory (no more false GO on base-branch code). Validate 5a edits and stages config files where the feature lives. |
| start-step-ordering | `edf6145` | Prerequisites and name collection come before the worktree step. `buildit-worktree` refuses an empty name and commits `.gitignore` via a pathspec. |

### Epic 2: Phase contracts
| Task | Commit | What changed |
|---|---|---|
| config-parsing-section-boundary | `141d0ba` | One "Config value rule" (read only within the heading, `#` lines are never values, empty = absent), restated verbatim by every consumer. An empty `## Test command` no longer runs `## Base branch` as a comment (silent test bypass). The bootstrap fast path still detects test command and base branch. |
| staging-contract | `4118918` | Build stages explicit paths and checks `git status --porcelain`. Validate runs the staging guard before tests and counts only `### NO-GO cycle` headings. Deliberate stops go to `## Last error`. |
| run-verifies-ship | `308026f` | Run records ref + SHA before ship and checks for a new commit plus the committed `.scratch/done/` file before touching plan.md or the external ticket. |
| tracking-file-discovery | `2fef64c` | Verbatim discovery rule (top-level `.scratch/`, `DD-MM-YYYY-<slug>.md`, exact slug, feature `## Status`, stop on ambiguity) in build/validate/ship/run, with a byte-identity test. Audit reports moved to `.scratch/audits/`. |
| mode-detection-single-source | `cfead53` | Operating mode comes from agent identity only (no `ls .claude/`), defined in team-practices and copied verbatim into 7 skills, with a drift test. |

### Epic 3: Bootstrap and skill integration
| Task | Commit | What changed |
|---|---|---|
| bootstrap-templates | `768e538` | Bootstrap creates `craft-principles.md`, 6 review dimensions, the full tracking-file sections, explicit-path staging and an anchored worktree permission. Run's autonomy text is defined once. |
| discover-plan-integration | `ae3dd01` | Discover scans detected source modules (not just `skills/`). Commands use the bare task name, and the shared Plan task lookup rule strips a leading `task-`. The manual flow documents plan updates. |

### Epic 4: Tests, docs and hygiene
| Task | Commit | What changed |
|---|---|---|
| cross-skill-contract-tests | `b6e0d5d` | Shared fence-aware helpers in `tests/lib/assertions.sh`, plus `tests/test-cross-skill-contracts.sh`. Vacuous whole-file regexes removed. The invariants test discovers skills from `skills/*/`. |
| docs-and-hygiene | `2db3816`, `fa5ec12` | README and team-practices realigned. Unused READY / Waiting for columns removed. `scripts/test_docs.sh` folded into `tests/test-readme.sh`. Minimal CI (`.github/workflows/tests.yml`). Design specs for feature-run, worktree mode and subagent isolation (removed later by the cleanup). The `.claude/CLAUDE.md` staging rule aligned. |

## Round 2 — 25-11-2026 audit and follow-ups
| Task | Commit | What changed |
|---|---|---|
| fix-audit-regressions | `f3ff8b0` | 11 regressions from round 1. Every `## Last error` writer replaces the section, and run clears it before each phase. Run stop reporting fixed. Start refuses to overwrite an existing tracking file. plan.md checkbox match anchored. Test helpers de-duplicated, `absent_in_text` guarded against empty sections. CI bounded. Contract tests scan every feature skill. |
| shared-context-local-state | `9e6f2d8` | `shared-context.md` becomes gitignored local state: start creates it, build/validate/ship treat absence as empty, ship never stages it (index surgery removed), and bootstrap gitignores and untracks it. |
| simplify-stops-legacy-harness | `f4d2d42` | feature-run is the only clearer of `## Last error`. Each writer skill defines its Deliberate stop procedure once. Ship reports only through `## Last error` (no more `SHIP BLOCKED:`). A missing `## Branch` is an explicit stop (legacy fallback dropped; git < 2.30 fallbacks kept). The `&&`/allow-rule explanation lives in the README only. |
| followups-stops-shared-context | `0907a9c` | project-audit and feature-discover tolerate a missing `shared-context.md`. Ship's subagent rule matches the Deliberate stop procedure. The README is the single home of the `&&` explanation. |

## Branch cleanup (this commit)
- The 17 per-task tracking files are replaced by this summary.
- `docs/buildit/specs/` (8 design specs) and `docs/buildit/reviews/` (1 historical audit) are removed, together with the guideline rule that required design specs. The WHY of a design choice is already recorded in the `.scratch/done/` tracking file (plan, decisions, retro), in the guidelines (durable conventions migrated at ship time) and in the commit messages. The specs were a fourth copy of the same reasoning, and they drifted each time a skill changed. The README, `.claude/CLAUDE.md` and `buildit-project-audit` references were removed. Tests now check that `docs/buildit/` is gone and no longer read the specs.

## Durable conventions introduced (now in guidelines)
- **Config value rule** — `language-framework.md`.
- **Operating mode rule**, **verbatim shared rule blocks + byte-identity tests**, **define repeated subagent text once** — `team-practices.md`.
- **Section-scoped, fence-aware assertions; no local extractors; cross-skill contracts tested as contracts** — `team-practices.md`.
- **README edited in place, headings unique** — `team-practices.md` (enforced by `test-readme.sh`).
- **`shared-context.md` is untracked local state** — `.claude/CLAUDE.md` and team-practices.

## Open points / known gaps
- Confirm `actions/checkout@v7` on the first CI run.
- Contract tests are structural (text level), not behavioural runs of the agents.
- A few local awk probes remain as documented exceptions (run AT-I6 "next line" getline, bootstrap AT-TB-2 dimension counter). The WRITERS list in the invariants test is hand-maintained.
- The config.md contract test does not check that each skill reads a heading only next to `.buildit/config.md`.
- Validate only mandates a Progress entry on NO-GO. A GO record is a convention, not a rule (raised by staging-contract's retro).
- `Bash(bash *)` permission for worktree-mode test commands is documented, not configured.

## Related local files (untracked, not part of this summary's commit)
- `.scratch/24-11-2026-audit-issues.md` — round 1 audit report.
- `.scratch/audits/25-11-2026-audit-issues.md` — round 2 audit report.
- `.scratch/plan/` — round 1 plan (13/13 tasks done).
