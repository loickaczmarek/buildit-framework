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

# AT-6: absent shared-context.md is treated as empty — no prerequisite stop
require_absent "AT-6: no 0a prerequisite check heading" "$SKILL" '^### 0a\. Prerequisite check'
require_absent "AT-6: no shared-context.md not found stop" "$SKILL" 'shared-context\.md not found'
require_absent "AT-6: no pointer to bootstrap for a missing shared-context" "$SKILL" 'Shared context file not found'
in_text "AT-6: step 1 treats an absent shared-context.md as empty" "$(section "$SKILL" '### 1. ' | normalize)" 'If `.scratch/shared-context.md` does not exist, treat it as empty'
in_text "AT-6: step 2 has nothing to clean when shared-context.md is absent" "$(section "$SKILL" '### 2. ' | normalize)" 'If `.scratch/shared-context.md` does not exist, treat it as empty'
DS=$(grep -F -- '**Deliberate stops:**' "$SKILL" || true)
absent_in_text "AT-6: Deliberate stops no longer lists the prerequisite check" "$DS" 'prerequisite check'
in_text "AT-6: Deliberate stops lists the migration note (0a)" "$DS" 'the migration note (0a)'
require_text "AT-6: environment paths step renumbered 0a" "$SKILL" '### 0a. Detect environment paths'
require_absent "AT-6: no dangling 0b step" "$SKILL" '^### 0b\.'

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
require_regex "AT-WT-3: copies the archived tracking file into the worktree before the commit" "$SKILL" '[Cc]opy.*\.scratch/done/.*into the worktree'
require_regex "AT-WT-4: guideline migrations and config updates happen in the worktree" "$SKILL" '<guidelines-dir>.*worktree|worktree.*<guidelines-dir>'
require_regex "AT-WT-5: removes root copy of the archived tracking file after commit" "$SKILL" '(remove|delete).*root copy'

# --- Blocked signal as a subagent (AT-SV-*) ---
require_text "AT-SV-2a: Running as a subagent section" "$SKILL" '## Running as a subagent'
require_text "AT-SV-2b: SHIP BLOCKED final message" "$SKILL" 'SHIP BLOCKED: <precise reason>'
require_text "AT-SV-2c: Last error line format" "$SKILL" 'buildit-feature-ship: blocked — <precise reason>'
require_text "AT-SV-2c: writes ## Last error" "$SKILL" '## Last error'
require_regex "AT-SV-2d: blocking verdict references the subagent rule" "$SKILL" 'If blocking.*subagent'
require_regex "AT-SV-2e: blocked path does not commit" "$SKILL" '[Dd]o not commit'
require_regex "AT-SV-2f: stale ## Last error removed at start" "$SKILL" 'remove.*## Last error|## Last error.*remove'
in_text "AT-SV-README: README ship section documents the blocked signal" "$(section README.md '### `buildit-feature-ship`')" 'SHIP BLOCKED'

# --- ## Branch contract (AT-BR-*) ---
SH0=$(section_body "$SKILL" '### 0. ')
SH1=$(section_body "$SKILL" '### 1. ')
SH2=$(section_body "$SKILL" '### 2. ')
if grep -qF -- '`## Branch`' <<<"$SH0" && grep -qF -- '<feature-branch>' <<<"$SH0"; then ok "AT-BR-4: step 0 reads ## Branch as <feature-branch>"; else fail "AT-BR-4: step 0 must read ## Branch as <feature-branch>"; fi
if grep -qiE -- 'legacy|fall back|falls back' <<<"$SH0" && grep -qF -- 'branch --show-current' <<<"$SH0"; then ok "AT-BR-4: legacy fallback when ## Branch is missing"; else fail "AT-BR-4: step 0 must define a legacy fallback when ## Branch is missing"; fi
if grep -qE -- 'other than `<feature-branch>`|skip.*<feature-branch>|<feature-branch>.*skip' <<<"$SH1"; then ok "AT-BR-4: overlap loop skips this feature's own branch"; else fail "AT-BR-4: overlap loop must skip <feature-branch>"; fi
if grep -qE -- 'Merge readiness.*remove.*<feature-branch>' <<<"$SH2"; then ok "AT-BR-4: step 2 removes the row for <feature-branch>"; else fail "AT-BR-4: step 2 must remove the Merge readiness row for <feature-branch>"; fi

# --- Closing commit built in execution order (AT-CC-*) ---
SH4=$(section_body "$SKILL" '### 4. ')
SH6=$(section_body "$SKILL" '### 6. ')

# AT-CC-1: shared-context.md is gitignored local state — ship never copies, stages nor commits it
require_absent "AT-CC-1: shared-context.md is never copied into the worktree" "$SKILL" '[Cc]opy `?\.scratch/shared-context\.md'
require_absent "AT-CC-1: no blanket staging of .scratch/" "$SKILL" 'add -A \.scratch/'
require_absent "AT-CC-1: no Shared-context rule" "$SKILL" 'Shared-context rule'
require_absent "AT-CC-1: no git hash-object" "$SKILL" 'hash-object'
require_absent "AT-CC-1: no git update-index" "$SKILL" 'update-index'
require_absent "AT-CC-1: never stages shared-context.md" "$SKILL" 'git (-C [^ ]+ )?add [^`]*\.scratch/shared-context\.md'
require_absent "AT-CC-1: no removal replay on the worktree's own copy" "$SKILL" "worktree's own"
in_text_re "AT-CC-1: step 4 states shared-context.md is never staged" "$(normalize <<<"$SH4")" '`\.scratch/shared-context\.md` is never staged'
in_text_re "AT-CC-1: step 4 says it is gitignored local state" "$(normalize <<<"$SH4")" 'gitignored local state'
in_text_re "AT-CC-1: step 2 still edits the project-root file" "$(normalize <<<"$SH2")" 'Edit the project root `\.scratch/shared-context\.md`'
in_text_re "AT-CC-1: step 2 still removes this feature's API section" "$SH2" 'API & Contracts modified.*remove'
in_text_re "AT-CC-1: step 2 still migrates then deletes" "$SH2" 'Migrate to the destination, then delete from shared-context\.md'
absent_in_text "AT-CC-1: step 6 no longer says the root file stays modified" "$SH6" 'stays modified'
in_text_re "AT-CC-1: step 6 says shared-context.md is untracked local state" "$(normalize <<<"$SH6")" 'untracked local coordination state'

# AT-CC-2: steps numbered in execution order, no amend
L2=$(line_of "$SKILL" '### 2. Clean shared-context'); L3=$(line_of "$SKILL" '### 3. Light retro'); L3b=$(line_of "$SKILL" '### 3b. Update configurations')
L4=$(line_of "$SKILL" '### 4. Stage'); L5=$(line_of "$SKILL" '### 5. Commit'); L6=$(line_of "$SKILL" '### 6. Worktree cleanup')
if [[ -n "$L2" && -n "$L3" && -n "$L3b" && -n "$L4" && -n "$L5" && -n "$L6" ]] && (( L2 < L3 && L3 < L3b && L3b < L4 && L4 < L5 && L5 < L6 )); then
  ok "AT-CC-2: steps ordered cleanup → retro → config update → stage → commit → worktree cleanup"
else
  fail "AT-CC-2: steps must be ### 2. Clean shared-context, ### 3. Light retro, ### 3b. Update configurations, ### 4. Stage, ### 5. Commit, ### 6. Worktree cleanup in that order"
fi
require_absent "AT-CC-2: no commit --amend" "$SKILL" 'commit --amend'
require_absent "AT-CC-2: no 'after step 4b' ordering constraint" "$SKILL" 'after step 4b'

# AT-CC-3: non-worktree path explicitly stages the moved tracking file
in_text_re "AT-CC-3: step 4 has an explicit Without worktree path" "$SH4" '\*\*Without worktree'
in_text_re "AT-CC-3: stages the archived tracking file" "$SH4" 'git add \.scratch/done/'

# AT-CC-4: WORKTREE_PATH read once at step 0, reused by worktree removal
in_text_re "AT-CC-4: step 0 stores WORKTREE_PATH" "$SH0" 'WORKTREE_PATH'
in_text_re "AT-CC-4: step 6 reuses WORKTREE_PATH" "$SH6" 'git worktree remove <WORKTREE_PATH>'
absent_in_text "AT-CC-4: step 6 does not re-read the tracking file" "$SH6" 'Read the `## Worktree path`'

# AT-CC-6: step 0 reads ## Worktree path before any use of <worktree-path>
RD=$(line_of <(echo "$SH0") '`## Worktree path`')
US=$(line_of <(echo "$SH0") '<worktree-path>')
if [[ -n "$RD" && -n "$US" ]] && (( RD <= US )); then ok "AT-CC-6: ## Worktree path read before <worktree-path> is used"; else fail "AT-CC-6: step 0 must read ## Worktree path before using <worktree-path>"; fi

# AT-CC-5: README ship section matches the new order and states the rule
RS=$(section_body README.md '### `buildit-feature-ship`' '---')
rl() { line_of <(echo "$RS") "$1"; }
R2=$(rl '**2. Shared-context'); R3=$(rl '**3. Light retro'); R4=$(rl '**4. Stage'); R5=$(rl '**5. Commit'); R6=$(rl '**6. Worktree')
if [[ -n "$R2" && -n "$R3" && -n "$R4" && -n "$R5" && -n "$R6" ]] && (( R2 < R3 && R3 < R4 && R4 < R5 && R5 < R6 )); then
  ok "AT-CC-5: README ship steps in execution order"
else
  fail "AT-CC-5: README ship section must list **2. Shared-context, **3. Light retro, **4. Stage, **5. Commit, **6. Worktree in order"
fi
absent_in_text "AT-CC-5: README no longer describes the removed staging rule" "$RS" "only this feature's removals|update-index|Shared-context rule"
in_text_re "AT-CC-5: README step 4 says shared-context.md is never staged" "$(normalize <<<"$RS")" '`shared-context\.md` is never staged'
absent_in_text "AT-CC-5: README readiness check has no prerequisite stop" "$RS" 'otherwise points to `/buildit-project-bootstrap`|0a'
in_text_re "AT-CC-5: README readiness check treats an absent file as empty" "$(normalize <<<"$RS")" 'absent.*empty'

require_absent "AT-CC-5: README no longer says ship copies its .scratch/ changes" README.md 'copies its `\.scratch/` changes'
require_absent "AT-CC-5: README has no superseded ship step '**2. Commit**'" README.md '^\*\*2\. Commit\*\*'
require_absent "AT-CC-5: README has no superseded ship cleanup '(in the same commit)'" README.md '\(in the same commit\)'
require_absent "AT-CC-5: README has no superseded retro 'included in the commit'" README.md 'the update is included in the commit'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
