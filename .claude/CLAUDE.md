# Project Rules

## Guidelines

Project guidelines are shared across agents in `.buildit/guidelines/`:
- `.buildit/guidelines/team-practices.md` — team conventions, naming, dual-deployment, commits
- `.buildit/guidelines/language-framework.md` — skill file format, Claude Code deployment, design specs
- `.buildit/guidelines/craft-principles.md` — DRY, KISS, YAGNI definitions used by build and validate

## Agent workflow
- Development loop: plan → self-critic → failing tests → execute → review → acceptance → commit
- Tracking files in `.scratch/` — format: `DD-MM-YYYY-feature-name.md`
- Status in each tracking file: to-build → building → to-validate → validating → to-ship (to-fix on NO-GO, loops back to building)
- Before setting status to `to-validate`, stage every file created or modified during the build (outside `.scratch/`) by explicit path, and confirm with `git status --porcelain` that no relevant untracked or unstaged file remains — the validate staging guard returns NO-GO otherwise.

## Parallel coordination
- `shared-context.md` structured in 4 sections (API & Contracts, Constraints, Decisions & Conventions, Merge readiness)
- `shared-context.md` is local, untracked state (gitignored) coordinating worktrees on a single machine — never committed
- Durable constraints and decisions → migrate into the appropriate guideline at ship time (committed with the feature)

## Git
- Branch convention: `feature/YYYY-MM-DD-name`, `bugfix/...`, `chore/...`
- Commit format: `type(scope): description` — explain the WHY
