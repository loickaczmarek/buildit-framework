---
name: buildit-worktree
description: "Use when creating an isolated git worktree for a feature — derives the branch name, creates the worktree under .worktrees/, resolves the absolute path, and instructs the calling agent to use git -C for all git operations inside it."
---

# Worktree Setup

Creates an isolated git worktree for a feature branch and returns the absolute path to the calling agent.

## When to use

Called internally by `buildit-feature-start` when the user opts into worktree isolation. Do not invoke directly unless setting up a worktree outside the standard buildit cycle.

## Arguments

```
/buildit-worktree [feature-name]
```

- `feature-name` — kebab-case slug used to derive the branch name and worktree directory

## Steps

### 0. Derive branch name

Run `date +%Y-%m-%d` to get today's date. Derive:

```
BRANCH=feature/YYYY-MM-DD-[feature-name]
WORKTREE_REL=.worktrees/feature/YYYY-MM-DD-[feature-name]
```

Example: for `feature-name=my-widget` on 2026-09-16 → `BRANCH=feature/2026-09-16-my-widget`, `WORKTREE_REL=.worktrees/feature/2026-09-16-my-widget`.

### 1. Ensure `.worktrees/` is in `.gitignore`

Check whether `.worktrees/` appears in `.gitignore`:

```bash
grep -q '\.worktrees/' .gitignore 2>/dev/null
```

- **Found** → continue
- **Not found** → append `.worktrees/` to `.gitignore` and commit:

```bash
echo '.worktrees/' >> .gitignore
git add .gitignore
git commit -m "chore(git): ignore .worktrees/ directory (worktree isolation)"
```

### 2. Create the worktree

```bash
git worktree add "$WORKTREE_REL" -b "$BRANCH"
```

Git creates intermediate directories automatically. The full on-disk path becomes `.worktrees/feature/YYYY-MM-DD-[feature-name]`.

If the worktree or branch already exists, report the error to the user and stop.

### 3. Resolve the absolute path

```bash
WORKTREE_PATH=$(realpath "$WORKTREE_REL" 2>/dev/null || (cd "$WORKTREE_REL" && pwd))
```

Store `WORKTREE_PATH` as the canonical absolute path to the worktree.

### 4. Return the path to the calling agent

Output exactly:

```
Worktree created at: <WORKTREE_PATH>
```

The calling agent must capture this line to record the path in the tracking file.

### 5. Instruct the calling agent on git usage

State explicitly to the calling agent:

> "Use `git -C <worktree-path>` for ALL git commands that must operate inside the worktree. Do NOT cd into the worktree for git operations — use the `-C` flag to target the correct working tree without changing directory."

Example:
```bash
git -C /abs/path/to/.worktrees/feature/2026-09-16-my-widget status
git -C /abs/path/to/.worktrees/feature/2026-09-16-my-widget add .
git -C /abs/path/to/.worktrees/feature/2026-09-16-my-widget commit -m "..."
```

## End of skill

> "Worktree created at `<WORKTREE_PATH>` on branch `<BRANCH>`. Use `git -C <WORKTREE_PATH>` for all git commands inside the worktree."
