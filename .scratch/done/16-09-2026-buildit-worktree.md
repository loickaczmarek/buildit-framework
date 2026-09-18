# buildit-worktree

## Status
to-ship

## Worktree path
none

## Goal
Internal skill `buildit-worktree` that replaces the external dependency on `superpowers:using-git-worktrees`. It handles worktree creation, enforces `git -C <path>` for git commands in subagents, records the worktree path in the tracking file, and updates `buildit-feature-start`, `buildit-feature-run`, `buildit-project-bootstrap` skills and README.

## Acceptance Tests
1. `buildit-worktree` creates a worktree in `.worktrees/<branch-name>` with branch `feature/YYYY-MM-DD-[feature-name]`
2. `buildit-worktree` returns the absolute worktree path to the calling agent
3. `buildit-worktree` explicitly instructs the agent to use `git -C <worktree-path>` for all git commands in that worktree
4. `buildit-feature-start` no longer references `using-git-worktrees` — it calls `buildit-worktree` instead
5. `buildit-feature-start` writes the worktree path in the tracking file (dedicated field)
6. `buildit-feature-run` includes `git -C <worktree-path>` in subagent prompts when `use-worktree=yes`
7. `buildit-feature-run` includes `Bash(cd */.worktrees/* && *)` in subagent autonomy instructions when `use-worktree=yes`
8. `buildit-project-bootstrap` adds `"Bash(cd */.worktrees/*)"` to the `permissions.allow` template in `settings.json`
9. `README.md` reflects that worktree management is internal to the framework
10. `tests/test-buildit-worktree.sh` covers content-assertable criteria

## Plan

### Files to create
- `skills/buildit-worktree/SKILL.md` (source)
- `.claude/skills/buildit-worktree/SKILL.md` (deployed, identical)
- `tests/test-buildit-worktree.sh`

### Files to modify
- `skills/buildit-feature-start/SKILL.md` (+ `.claude/` mirror)
- `skills/buildit-feature-run/SKILL.md` (+ `.claude/` mirror)
- `skills/buildit-project-bootstrap/SKILL.md` (+ `.claude/` mirror)
- `tests/test-skills-invariants.sh`
- `README.md`

### Step 1 — Create `buildit-worktree` skill
The skill:
- Frontmatter: `name: buildit-worktree`, `description: ...`
- Takes `feature-name` as argument
- Step 0: Derive branch name `feature/YYYY-MM-DD-[feature-name]` using `date +%Y-%m-%d`
- Step 1: Verify `.worktrees/` is in `.gitignore` — if not, append it and commit the change
- Step 2: Create the worktree: `git worktree add .worktrees/feature/YYYY-MM-DD-[feature-name] -b feature/YYYY-MM-DD-[feature-name]`. Note: git creates the nested `.worktrees/feature/` directory automatically. The full on-disk path is `.worktrees/feature/YYYY-MM-DD-[feature-name]`.
- Step 3: Resolve absolute path — prefer `realpath`; fallback: `$(cd .worktrees/feature/YYYY-MM-DD-[feature-name] && pwd)`. Store as `WORKTREE_PATH`.
- Step 4: Output the absolute path to the calling agent with a clear label: "Worktree created at: <WORKTREE_PATH>"
- Step 5: Instruct the calling agent explicitly: "Use `git -C <worktree-path>` for ALL git commands that must operate inside the worktree. Do NOT cd into the worktree."
- `## Steps` and `## End of skill` sections required for invariants

### Step 2 — Update `buildit-feature-start`
- Step 0: Replace "invoke `using-git-worktrees`" with "invoke `buildit-worktree [feature-name]`" (pass feature-name so the skill can derive the branch name)
- Step 0 (Yes branch): Capture the returned absolute worktree path (the "Worktree created at: ..." line in the skill output)
- Step 3 (Generate tracking file template): Add `## Worktree path` field between `## Status` and `## Goal`. Write the captured path (or "none" if no worktree). This is the primary data source for subsequent skills.
- Mirror all changes to `.claude/skills/buildit-feature-start/SKILL.md`

### Step 3 — Update `buildit-feature-run`
- Step 3 (Detect tracking file): Read `## Worktree path` from tracking file as primary source; `git worktree list` remains as secondary/verification. The start subagent creates the worktree — build/validate/ship subagents consume it.
- Steps 4 build/validate/ship subagent prompts: When `use-worktree=yes`, append to the autonomy instruction block:
  - "For git commands inside the worktree, use `git -C <worktree-path>` instead of cd."
  - "The following permission is required in settings.json: `Bash(cd */.worktrees/* && *)`" — use this exact string so the test can grep it verbatim.
- The start subagent prompt does NOT need `git -C` (worktree does not yet exist at that point).
- Mirror all changes to `.claude/skills/buildit-feature-run/SKILL.md`

### Step 4 — Update `buildit-project-bootstrap`
- In the Absent-case JSON template: add `"Bash(cd */.worktrees/*)"` to `permissions.allow` array (after the existing `"Bash(cd ./*)"` entry)
- In the Found-case audit list: add `"Bash(cd */.worktrees/*)"` as an essential rule to check (worktree subagents need it)
- Update the note about worktree permissions to mention this new pattern
- Mirror all changes to `.claude/skills/buildit-project-bootstrap/SKILL.md`

### Step 5 — Update `README.md`
- Autonomy config / settings.json template: add `"Bash(cd */.worktrees/*)"` to the template
- Skills section for `buildit-feature-start`: update to say it calls the internal `buildit-worktree` skill (no external dependency on `superpowers:using-git-worktrees`)
- Add `buildit-worktree` as a listed skill with its trigger and description
- Parallelisation section: note that the framework now manages worktrees internally via `buildit-worktree`

### Step 6 — Create `tests/test-buildit-worktree.sh`
Content-assertable checks:
- AT-1: SKILL.md mentions `.worktrees/` and `feature/YYYY-MM-DD`
- AT-2: SKILL.md mentions absolute path output (realpath or absolute)
- AT-3: SKILL.md mentions `git -C`
- AT-4: `buildit-feature-start` SKILL.md does NOT reference `using-git-worktrees`, DOES reference `buildit-worktree`
- AT-5: `buildit-feature-start` SKILL.md has `## Worktree path` in tracking file template
- AT-6: `buildit-feature-run` SKILL.md mentions `git -C` in worktree context
- AT-7: `buildit-feature-run` SKILL.md mentions `Bash(cd */.worktrees/*`
- AT-8: `buildit-project-bootstrap` SKILL.md mentions `Bash(cd */.worktrees/*)`
- AT-9: `README.md` mentions `buildit-worktree` as internal skill

### Step 7 — Update `tests/test-skills-invariants.sh`
- Add `buildit-worktree` to the SKILLS array

## Progress

<!-- empty at start -->
