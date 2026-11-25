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

# AT-6: absent shared-context.md is created from the 4-section template — no stop
PRE=$(section "$SKILL" '### 0. Ensure shared-context.md exists')
in_text "AT-6: step 0 creates shared-context.md from the template when absent" "$(normalize <<<"$PRE")" 'If `.scratch/shared-context.md` does not exist, create it from the template below'
absent_in_text "AT-6: step 0 does not stop and point to bootstrap" "$PRE" 'run `/buildit-project-bootstrap`|Shared context file not found'
in_text "AT-6: step 0 says the file is local, untracked state" "$(normalize <<<"$PRE")" 'local, untracked'
SC_TPL=$(fenced_block "$SKILL" '# Shared Context')
for h in '## API & Contracts modified' '## Constraints discovered' '## Decisions & Conventions' '## Merge readiness' '| Branch | Status | Main files touched |'; do
  in_text "AT-6: shared-context template has '$h'" "$SC_TPL" "$h"
done
in_text "AT-6: template lives in step 0" "$PRE" '# Shared Context'
if grep -E '^description:' "$SKILL" | grep -qF 'creates .scratch/shared-context.md if absent'; then ok "AT-6: description mentions creation if absent"; else fail "AT-6: description must mention 'creates .scratch/shared-context.md if absent'"; fi

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
L_PRE=$(grep -nE '^### [0-9]+b?\. Ensure shared-context\.md exists' "$SKILL" | head -1 | cut -d: -f1 || true)
L_COLLECT=$(grep -nE '^### [0-9]+b?\. Collect feature information' "$SKILL" | head -1 | cut -d: -f1 || true)
L_WTSTEP=$(grep -nE '^### [0-9]+b?\. Worktree' "$SKILL" | head -1 | cut -d: -f1 || true)
L_INVOKE=$(grep -nF -- 'buildit-worktree [feature-name]' "$SKILL" | head -1 | cut -d: -f1 || true)
if [[ -n "$L_PRE" && -n "$L_COLLECT" && -n "$L_WTSTEP" && "$L_PRE" -lt "$L_COLLECT" && "$L_COLLECT" -lt "$L_WTSTEP" ]]; then
  ok "AT-ORD-1: shared-context step → feature name collection → worktree step"
else
  fail "AT-ORD-1: order must be shared-context step → collect → worktree (pre=$L_PRE collect=$L_COLLECT worktree=$L_WTSTEP)"
fi
require_absent "AT-ORD-1: worktree step is not step 0" "$SKILL" '^### 0\. Worktree'
if [[ -n "$L_INVOKE" && -n "$L_WTSTEP" && "$L_INVOKE" -gt "$L_WTSTEP" ]]; then
  ok "AT-ORD-1: buildit-worktree is invoked within the worktree step"
else
  fail "AT-ORD-1: buildit-worktree must be invoked within the worktree step (invoke=$L_INVOKE worktree=$L_WTSTEP)"
fi
require_regex "AT-ORD-2: worktree step runs once the feature name is collected" "$SKILL" 'feature name is (already )?(collected|known)'
require_regex "AT-ORD-2: empty feature name is re-asked" "$SKILL" '[Ee]mpty.*(ask again|re-ask)'

# AT-EX: an existing tracking file for the same name stops start before anything is created
S2=$(section "$SKILL" '### 2. Collect feature information' | normalize)
in_text "AT-EX-1: step 2 guards against an existing tracking file" "$S2" '**Existing tracking file:**'
in_text "AT-EX-2: guard uses the exact-slug file pattern at top level" "$S2" 'the top level of `.scratch/` already holds a file named `DD-MM-YYYY-<feature-name>.md`'
in_text "AT-EX-3: guard never looks into done/ nor matches substrings" "$S2" 'never `.scratch/done/`, never a substring match'
in_text "AT-EX-4: guard stops with an already-exists message" "$S2" 'already exists'
in_text "AT-EX-5: guard never overwrites" "$S2" 'Nothing is created or overwritten'
before "AT-EX-6: guard precedes the worktree step" "$SKILL" '**Existing tracking file:**' '### 2b. Worktree?'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
