# Team Practices

## Skill authoring

Skills are markdown files defining agent workflows. Each skill lives in its own directory:
- Canonical source: `skills/<skill-name>/SKILL.md`
- Deployed copy: `.claude/skills/<skill-name>/SKILL.md`

Both files must be kept in sync at every commit. Changes to a skill are always made in `skills/` first, then mirrored to `.claude/skills/`.

All skill files must be authored in English. User-facing messages, field labels, step descriptions, and inline comments must not contain strings in any other language.

## Documentation requirements

For each feature, the agent must derive documentation acceptance tests from the table below during `buildit-feature-start`.

| Change type | README.md | Design spec (`docs/<domain>/specs/YYYY-MM-DD-name.md`) |
|-------------|-----------|--------------------------------------------------------|
| New skill | Required — add to overview diagram and skills list | Required if non-obvious design choices (isolation, state, signal-passing, workaround) |
| Skill modification | Required if the interface or trigger changes | Required if a new non-obvious pattern is introduced |
| Framework change (guidelines, test harness, hooks, scripts) | Required if the workflow or setup steps change | Not required |
| Bugfix | Not required | Not required |

When in doubt about whether a design spec is warranted, write it. A short spec is better than a missing one.

## Naming conventions

- Skill directory names: kebab-case (e.g. `buildit-feature-start`)
- Skill file: `SKILL.md` (uppercase, no variant)
- Design spec docs: `docs/<domain>/specs/YYYY-MM-DD-kebab-name.md`
- Tracking files: `.scratch/DD-MM-YYYY-feature-name.md`

## Setup

After cloning the repository, configure git to use the repo's tracked hooks:

```bash
bash scripts/install-hooks.sh
```

This sets `core.hooksPath` to `scripts/hooks/` in the local git config, so git picks up hooks directly from the tracked directory — no file copying needed. The pre-push hook runs `tests/run-all.sh` before every `git push` and aborts the push if any test fails. Use `git push --no-verify` to bypass in exceptional cases.

## Testing

No automated test framework. Skills are validated by:
1. Manual invocation in a real Claude Code session
2. Reviewing agent behaviour against acceptance tests defined in the tracking file

For skills whose acceptance criteria are content-checkable, structural bash scripts (`tests/test-*.sh`) serve as the TDD "failing test" artefact. Each script maps one-to-one to an acceptance criterion and uses `grep` against the `SKILL.md` content. This makes criteria machine-verifiable without introducing a test runner dependency.

### Test harness conventions

Shared assertion helpers live in `tests/lib/assertions.sh` and must be sourced at the top of every `tests/test-*.sh` file:

```bash
source "$(dirname "$0")/lib/assertions.sh"
```

The library exposes: `ok`, `fail`, `require_file`, `require_text`, `require_regex`. Each test file initialises `PASS`/`FAIL` counters via that source — never inline. This avoids duplicating helper definitions across test files while keeping zero external dependencies.

`tests/run-all.sh` is the single entry point: runs all `test-*.sh` files and exits non-zero if any file fails, printing a combined `Total: X passed, Y failed` summary.

New test files follow the naming pattern `tests/test-<skill-name>.sh`.

## Review

Mandatory evaluation dimensions:
- Correctness: does the skill do what is specified?
- Performance: unnecessary steps or costly operations?
- Security: injection vectors, data exposure?
- Style: naming and format conventions respected?
- Coverage: edge cases addressed in acceptance tests?

## Commits

Format: `type(scope): short description`
Types: feat, fix, chore, refactor, test, docs
The commit description explains the WHY, not the what.

## Branches

- `feature/YYYY-MM-DD-short-name`
- `bugfix/YYYY-MM-DD-short-name`
- `chore/YYYY-MM-DD-short-name`

## .scratch/

File name format: `DD-MM-YYYY-feature-name.md`
Move to `.scratch/done/` at the closing commit.

Tracking file sections: Status · Goal · Acceptance Tests · Plan · Progress · Problems to fix
Status flow: to-build → building → to-validate → validating → to-ship (to-fix on NO-GO, loops back to building)
Progress: one entry per NO-GO cycle, added by feature-validate
