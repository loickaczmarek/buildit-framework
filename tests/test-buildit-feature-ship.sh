#!/usr/bin/env bash
# Structural tests for the buildit-feature-ship skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-ship/SKILL.md"

# AT-1: Cleans shared-context.md at close (Merge readiness + API sections)
require_text "AT-1: cleans Merge readiness section" "$SKILL" 'Merge readiness'
require_regex "AT-1: removes API & Contracts section for branch" "$SKILL" 'API & Contracts'

# AT-2: Migrates durable constraints to guidelines
require_regex "AT-2: migrates durable constraints" "$SKILL" '(durable|migrate|Migrate)'

# AT-3: Does NOT push or create the PR (explicit in skill)
require_regex "AT-3: does not push or create PR" "$SKILL" '(Push|push).*(manual|yours|not)'

# AT-4: Ship computes file overlap for each IN_PROGRESS branch via git diff
require_text "AT-4: per-branch overlap via git diff vs base branch" "$SKILL" 'git diff --name-only --merge-base <base-branch> <branch>'

# AT-5: Ship instructs to compare touched files between branches dynamically
require_regex "AT-5: dynamic overlap for IN_PROGRESS branches" "$SKILL" 'IN_PROGRESS.*diff|diff.*IN_PROGRESS|each.*branch.*--name-only'

# AT-6: Shared-context existence check — stops if shared-context.md missing
require_regex "AT-6: checks shared-context.md existence" "$SKILL" 'shared-context\.md.*(not exist|does not exist|missing)|exist.*shared-context\.md'
require_text "AT-6: tells user to run /buildit-project-bootstrap" "$SKILL" '/buildit-project-bootstrap'

# AT-7: Worktree cleanup — removes worktree after commit
require_text "AT-7: reads Worktree path from tracking file" "$SKILL" 'Worktree path'
require_text "AT-7: uses git worktree remove" "$SKILL" 'git worktree remove'

# --- Base branch and staged feature diff (AT-BASE-*) ---
require_text "AT-BASE-1: feature file list covers staged work vs base branch" "$SKILL" 'git diff --cached --merge-base <base-branch> --name-only'
require_regex "AT-BASE-2: documents commits-only limitation of the overlap check" "$SKILL" 'only (sees|compares) commit|commits only|committed work only'
require_text "AT-BASE-3: git < 2.30 fallback" "$SKILL" 'git merge-base <base-branch>'
require_text "AT-BASE-3: fallback names git 2.30" "$SKILL" '2.30'
require_absent "AT-BASE-4: no hardcoded main..." "$SKILL" 'main\.\.'
require_text "AT-BASE-5: reads ## Base branch" "$SKILL" '## Base branch'
require_regex "AT-BASE-5: defaults to main" "$SKILL" 'defaults? to `main`|falls? back to `main`'

# --- Worktree working directory (AT-WT-*) ---
require_text "AT-WT-1: git commands target the worktree" "$SKILL" 'git -C <worktree-path>'
require_regex "AT-WT-2: .scratch/ and config.md are read from the project root" "$SKILL" '`\.scratch/` and `\.buildit/config\.md`.*project root'
require_regex "AT-WT-3: copies .scratch/ changes into the worktree before the commit" "$SKILL" '[Cc]opy.*\.scratch/.*into the worktree'
require_regex "AT-WT-4: guideline migrations and amend happen in the worktree" "$SKILL" '<guidelines-dir>.*worktree|worktree.*<guidelines-dir>'
require_regex "AT-WT-5: removes root copy of the archived tracking file after commit" "$SKILL" '(remove|delete).*root copy'

# --- Blocked signal as a subagent (AT-SV-*) ---
require_text "AT-SV-2a: Running as a subagent section" "$SKILL" '## Running as a subagent'
require_text "AT-SV-2b: SHIP BLOCKED final message" "$SKILL" 'SHIP BLOCKED: <precise reason>'
require_text "AT-SV-2c: Last error line format" "$SKILL" 'buildit-feature-ship: blocked — <precise reason>'
require_text "AT-SV-2c: writes ## Last error" "$SKILL" '## Last error'
require_regex "AT-SV-2d: blocking verdict references the subagent rule" "$SKILL" 'If blocking.*subagent'
require_regex "AT-SV-2e: blocked path does not commit" "$SKILL" '[Dd]o not commit'
require_regex "AT-SV-2f: stale ## Last error removed at start" "$SKILL" 'remove.*## Last error|## Last error.*remove'
if awk '/^### `buildit-feature-ship`/{f=1;next} f&&/^### /{exit} f' README.md | grep -qF 'SHIP BLOCKED'; then
  ok "AT-SV-README: README ship section documents the blocked signal"
else
  fail "AT-SV-README: README ship section must document SHIP BLOCKED"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
