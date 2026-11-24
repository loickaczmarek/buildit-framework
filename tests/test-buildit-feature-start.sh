#!/usr/bin/env bash
# Structural tests for the buildit-feature-start skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-start/SKILL.md"

# AT-1: Reads shared-context.md before planning
require_text "AT-1: reads shared-context.md before planning" "$SKILL" 'shared-context.md'

# AT-2: Tracking file template includes to-build as initial status
TPL_STATUS=$(fenced_block "$SKILL" '# [feature-name]' | grep -A1 -x '## Status' | tail -n +2)
[[ "$TPL_STATUS" == "to-build" ]] && ok "AT-2: tracking file template has to-build status" || fail "AT-2: template status must be to-build (got '$TPL_STATUS')"

# AT-3: Handoff instruction references /buildit-feature-build
require_text "AT-3: handoff references /buildit-feature-build" "$SKILL" '/buildit-feature-build'

# AT-4: Plan includes a self-critic step
require_regex "AT-4: self-critic step present" "$SKILL" '(self-critic|self.critic|Self-critic)'

# AT-5: Tracking file name format uses DD-MM-YYYY
require_regex "AT-5: tracking file uses DD-MM-YYYY format" "$SKILL" 'DD-MM-YYYY'

# AT-6: Shared-context existence check — stops if shared-context.md missing
PRE=$(section "$SKILL" '### 0. Prerequisite check')
in_text "AT-6: prerequisite check tests shared-context.md existence" "$PRE" 'If `.scratch/shared-context.md` does not exist, stop'
in_text "AT-6: prerequisite check points to /buildit-project-bootstrap" "$PRE" 'run `/buildit-project-bootstrap`'

# --- Worktree working directory (AT-WT-*) ---
require_regex "AT-WT-1: .scratch/ files stay in the project root in worktree mode" "$SKILL" '`\.scratch/`.*stay.*project root'

# --- ## Branch contract (AT-BR-*) ---
L_STATUS=$(line_of "$SKILL" '## Status'); L_BRANCH=$(line_of "$SKILL" '## Branch'); L_WT=$(line_of "$SKILL" '## Worktree path')
if [[ -n "$L_BRANCH" && -n "$L_STATUS" && -n "$L_WT" && "$L_STATUS" -lt "$L_BRANCH" && "$L_BRANCH" -lt "$L_WT" ]]; then
  ok "AT-BR-1: template has ## Branch between ## Status and ## Worktree path"
else
  fail "AT-BR-1: template must have ## Branch between ## Status and ## Worktree path (status=$L_STATUS branch=$L_BRANCH worktree=$L_WT)"
fi
require_regex "AT-BR-1: worktree mode takes the branch from buildit-worktree's Branch: line" "$SKILL" '`Branch: <BRANCH>`.*`BRANCH`'
require_regex "AT-BR-1: no-worktree mode takes the branch from git branch --show-current" "$SKILL" '`BRANCH`.*git branch --show-current|git branch --show-current.*`BRANCH`'
require_regex "AT-BR-1: detached HEAD stops" "$SKILL" '[Dd]etached HEAD.*stop|stop.*[Dd]etached HEAD'
require_text "AT-BR-1: ## Branch contract documented" "$SKILL" '**`## Branch` contract**'
require_regex "AT-BR-1: ## Branch is never rewritten by other phases" "$SKILL" 'never rewritten'
S5=$(section "$SKILL" '### 5.')
if grep -qF -- '`## Branch`' <<<"$S5"; then ok "AT-BR-2: step 5 keys the row with ## Branch"; else fail "AT-BR-2: step 5 must key the row with ## Branch"; fi
if grep -qF -- 'git branch --show-current' <<<"$S5"; then fail "AT-BR-2: step 5 must not read git branch --show-current"; else ok "AT-BR-2: step 5 does not read git branch --show-current"; fi
if grep -qE -- 'after the worktree' <<<"$S5"; then ok "AT-BR-2: step 5 runs after the worktree exists"; else fail "AT-BR-2: step 5 must state it runs after the worktree exists"; fi

# --- Step ordering (AT-ORD-*) ---
L_PRE=$(grep -nE '^### [0-9]+b?\. Prerequisite check' "$SKILL" | head -1 | cut -d: -f1 || true)
L_COLLECT=$(grep -nE '^### [0-9]+b?\. Collect feature information' "$SKILL" | head -1 | cut -d: -f1 || true)
L_WTSTEP=$(grep -nE '^### [0-9]+b?\. Worktree' "$SKILL" | head -1 | cut -d: -f1 || true)
L_INVOKE=$(grep -nF -- 'buildit-worktree [feature-name]' "$SKILL" | head -1 | cut -d: -f1 || true)
if [[ -n "$L_PRE" && -n "$L_COLLECT" && -n "$L_WTSTEP" && "$L_PRE" -lt "$L_COLLECT" && "$L_COLLECT" -lt "$L_WTSTEP" ]]; then
  ok "AT-ORD-1: prerequisite check → feature name collection → worktree step"
else
  fail "AT-ORD-1: order must be prerequisite check → collect → worktree (pre=$L_PRE collect=$L_COLLECT worktree=$L_WTSTEP)"
fi
require_absent "AT-ORD-1: worktree step is not step 0" "$SKILL" '^### 0\. Worktree'
if [[ -n "$L_INVOKE" && -n "$L_WTSTEP" && "$L_INVOKE" -gt "$L_WTSTEP" ]]; then
  ok "AT-ORD-1: buildit-worktree is invoked within the worktree step"
else
  fail "AT-ORD-1: buildit-worktree must be invoked within the worktree step (invoke=$L_INVOKE worktree=$L_WTSTEP)"
fi
require_regex "AT-ORD-2: worktree step runs once the feature name is collected" "$SKILL" 'feature name is (already )?(collected|known)'
require_regex "AT-ORD-2: empty feature name is re-asked" "$SKILL" '[Ee]mpty.*(ask again|re-ask)'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
