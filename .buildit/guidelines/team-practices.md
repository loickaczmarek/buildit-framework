# Team Practices

## Skill authoring

Skills are markdown files defining agent workflows. Each skill lives in its own directory:
- Canonical source: `skills/<skill-name>/SKILL.md`
- Deployed copy: `.claude/skills/<skill-name>/SKILL.md`

Both files must be kept in sync at every commit. Changes to a skill are always made in `skills/` first, then mirrored to `.claude/skills/`.

## Naming conventions

- Skill directory names: kebab-case (e.g. `buildit-feature-start`)
- Skill file: `SKILL.md` (uppercase, no variant)
- Design spec docs: `docs/<domain>/specs/YYYY-MM-DD-kebab-name.md`
- Tracking files: `.scratch/DD-MM-YYYY-feature-name.md`

## Testing

No automated test framework. Skills are validated by:
1. Manual invocation in a real Claude Code session
2. Reviewing agent behaviour against acceptance tests defined in the tracking file

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
