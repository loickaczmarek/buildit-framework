# Project Rules

## Guidelines

Project guidelines are shared across agents in `.buildit/guidelines/`:
- `.buildit/guidelines/team-practices.md` — team conventions, naming, dual-deployment, commits
- `.buildit/guidelines/language-framework.md` — skill file format, Claude Code deployment, design specs

## Agent workflow
- Development loop: plan → self-critic → failing tests → execute → review → acceptance → commit
- Tracking files in `.scratch/` — format: `DD-MM-YYYY-feature-name.md`
- Status in each tracking file: to-build → building → to-validate → validating → to-ship (to-fix on NO-GO, loops back to building)

## Parallel coordination
- `shared-context.md` structured in 4 sections (API & Contracts, Constraints, Decisions & Conventions, Merge readiness)
- Cleaning `shared-context.md` mandatory in the closing commit
- Durable constraints → migrate into the appropriate guideline at commit

## Git
- Branch convention: `feature/YYYY-MM-DD-name`, `bugfix/...`, `chore/...`
- Commit format: `type(scope): description` — explain the WHY
