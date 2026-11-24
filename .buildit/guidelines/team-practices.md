# Team Practices

## Skill authoring

### Orchestrator-level permission trigger

When a skill orchestrates subagents and the first tool-permission-gated operation would otherwise occur inside a subagent, move a real write to an existing coordination file (e.g. `shared-context.md`) into the orchestrator before launching subagents, and pass a "skip" instruction to the subagent to avoid duplication. This surfaces the permission prompt immediately at session start rather than midway through a subagent, improving UX for users who have not pre-allowed permissions.

### Plan-task integration in orchestrators

When `buildit-feature-run` receives a `feature-name` argument, it checks for a matching `.scratch/plan/task-{feature-name}.md` file and manages the task's status lifecycle automatically: `todo` -> `in-progress` at step 0, `in-progress` -> `done` at step 6 (after ship). Plan.md checkbox and progress counters are re-synced at each transition. If no matching task file exists, the orchestrator falls through to existing behavior unchanged.

`buildit-feature-discover` applies the same detection when it receives a `feature-name`: it scopes the task starting from its description and acceptance tests, then on brief validation writes the brief into the task file, sets `## Readiness` to `ready`, and switches the plan.md tag from `[needs-scoping]` to `[ready]`. Field ownership is strict: `## Readiness` (and the plan.md readiness tag) is owned by `buildit-feature-discover`; `## Status` (and the plan.md checkbox and progress counters) is owned by `buildit-feature-run`. Neither skill writes the other's field.

Field ownership extends to external writes when task synchronization is enabled (see `buildit-plan` step 5b): `buildit-feature-run` writes only Status, `buildit-feature-discover` writes only Description, Acceptance tests and Readiness, and only `buildit-plan` performs the full bidirectional reconcile. External writes happen from the orchestrator (never inside a subagent), after one explicit confirmation per invocation, and only for tasks with a `Link:`. A refusal or failure writes a `Pending:` entry in the task's `## Synchronization` section and never blocks the local flow. Run and discover never prompt to configure synchronization.

### Worktree management

Worktree management is handled internally by the `buildit-worktree` skill. Skills and orchestrators must **not** reference `superpowers:using-git-worktrees` or any external worktree tooling. The framework must remain self-contained; an external dependency on `superpowers:using-git-worktrees` creates a fragile coupling that silently breaks worktree isolation when the skill is absent or changes.

### Parallel category subagents

When a skill evaluates independent dimensions or domains, group them into parallel category subagents rather than a single sequential pass. Launch all subagents in a single message with multiple Agent tool calls. Each category's findings should be critiqued independently by a dedicated critique subagent that receives only that category's findings — this ensures deeper, focused critique and prevents cross-category contamination. See `docs/buildit/specs/2026-10-19-audit-parallel-pipeline.md` for the full design rationale.

### Subagent selection and workflow isolation

Every subagent launched by a skill uses the neutral `general-purpose` agent type. Each skill that launches subagents defines an **Isolation preamble** once, as a named block in a "Subagent selection and workflow isolation" section, and every launch step references that block instead of repeating it. Each skill stays self-contained: there is no include mechanism. The preamble keeps the subagent neutral, so it adopts no persona and does not swap in another workflow. It also forbids invoking any skill or agent except the buildit skills and subagents the delegated skill explicitly references or instructs it to launch (e.g. `buildit-worktree`, the validate §5a config-update subagent). If `general-purpose` is not available in the harness, fall back to the harness's default unspecialised subagent, still include the preamble, and warn the user once. Never fall back to a specialised persona agent. Why: persona agents or unrelated skills must not take over delegated buildit workflows, and the framework must stay portable across harnesses.

### Restriction wording in delegated-subagent preambles

When an orchestrator puts restriction text in front of a wrapped skill's prompt (e.g. "do not invoke any skill or agent"), the exemptions must cover every kind of delegation the wrapped skill itself requires. That means the skills it references *and* the subagents/agents it explicitly tells the agent to launch (e.g. a `general-purpose` config-update subagent). Before finalising the wording, read each wrapped skill and list every skill invocation and agent launch it requires. A ban that a strictly obedient subagent would read as forbidding one of those steps is a correctness bug, because the step gets skipped or done inline. Keep every restatement of the rule (README, `shared-context.md` decisions, design spec) worded exactly like the preamble.

Skills are markdown files defining agent workflows. Each skill lives in its own directory:
- Canonical source: `skills/<skill-name>/SKILL.md`
- Deployed copy: `.claude/skills/<skill-name>/SKILL.md`

Both files must be kept in sync at every commit. Changes to a skill are always made in `skills/` first, then mirrored to `.claude/skills/`. In this repository `.claude/skills` is a tracked symlink to `../skills`, so the deployed copy is in sync by construction — edit `skills/` only, never `cp` over the symlinked path; `diff -q` remains a valid sanity check.

**Single source of truth for guideline references.** When a skill needs to document a concept or definition (e.g. craft principles, naming conventions), the canonical text lives in the appropriate guideline file under `.buildit/guidelines/`. The skill file references that guideline by path — it does not copy the content. This avoids DRY violations (diverging definitions) and ensures a single edit point when definitions evolve.

All skill files must be authored in English. User-facing messages, field labels, step descriptions, and inline comments must not contain strings in any other language.

### Path and mode conventions

**No hardcoded absolute paths.** Skills must never embed machine-specific or project-specific absolute paths. Use `pwd` to detect the project root at runtime and store it as `PROJECT_ROOT`.

**Operating mode detection.** Skills that reference agent-specific directories (skills dir, rules file, permissions config) must detect their mode at step 0:
- Run `ls .claude/ 2>/dev/null` — if the directory exists → **Claude mode**, use `.claude/` paths
- Otherwise → **Generic mode**, use `.agents/` paths

| Resource | Claude mode | Generic mode |
|----------|-------------|--------------|
| Rules file | `.claude/CLAUDE.md` | `.agents/guidelines/project-rules.md` |
| Skills directory | `.claude/skills/` | `.agents/skills/` |
| Autonomy settings | `.claude/settings.json` | Copilot permissions config |

Skills that do not reference any mode-specific paths (e.g. pure orchestrators that invoke other skills by name) still must not hardcode absolute paths.

## Shared-context coordination

`shared-context.md` has no locking mechanism. When running parallel features, ensure only one skill session writes to this file at a time. Stagger phases that modify `shared-context.md` (start, build capture, ship cleanup) to avoid overwrites. Each skill that writes to `shared-context.md` includes a sequential access warning before the write operation.

## Documentation requirements

For each feature, the agent must derive documentation acceptance tests from the table below during `buildit-feature-start`.

| Change type | README.md | Design spec (`docs/<domain>/specs/YYYY-MM-DD-name.md`) |
|-------------|-----------|--------------------------------------------------------|
| New skill | Required — add to overview diagram and skills list | Required if non-obvious design choices (isolation, state, signal-passing, workaround) |
| Skill modification | Required if the interface or trigger changes | Required if a new non-obvious pattern is introduced |
| Framework change (guidelines, test harness, hooks, scripts) | Required if the workflow or setup steps change | Not required |
| Bugfix | Not required | Not required |

When in doubt about whether a design spec is warranted, write it. A short spec is better than a missing one.

**README consistency on structural changes.** The "Skill modification" row above covers trigger/interface changes, but the README's "What it does" section also enumerates internal steps. When a feature modifies the step structure of a skill (adding, removing, reordering, or fundamentally changing steps), update the corresponding README section in the same commit — even if the trigger and external interface are unchanged. Treat the SKILL.md steps and their README summary as a coupled pair: never modify one without checking the other.

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

Section comments that name a range of test IDs (e.g. "AT-I1 through AT-I6") must match the tests actually defined in that section. Update the comment in the same change whenever you add, remove or renumber a test in the section.

## Review

Mandatory evaluation dimensions:
- Correctness: does the skill do what is specified?
- Performance: unnecessary steps or costly operations?
- Security: injection vectors, data exposure?
- Style: naming and format conventions respected?
- Coverage: edge cases addressed in acceptance tests?
- Craft principles: does the implementation respect DRY, KISS, and YAGNI? (see `.buildit/guidelines/craft-principles.md` for canonical definitions and failure modes)

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
