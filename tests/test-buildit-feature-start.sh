#!/usr/bin/env bash
# Structural tests for the buildit-feature-start skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-start/SKILL.md"

# AT-1: Reads shared-context.md before planning
require_text "AT-1: reads shared-context.md before planning" "$SKILL" 'shared-context.md'

# AT-2: Tracking file template includes to-build as initial status
require_text "AT-2: tracking file template has to-build status" "$SKILL" 'to-build'

# AT-3: Handoff instruction references /buildit-feature-build
require_text "AT-3: handoff references /buildit-feature-build" "$SKILL" '/buildit-feature-build'

# AT-4: Plan includes a self-critic step
require_regex "AT-4: self-critic step present" "$SKILL" '(self-critic|self.critic|Self-critic)'

# AT-5: Tracking file name format uses DD-MM-YYYY
require_regex "AT-5: tracking file uses DD-MM-YYYY format" "$SKILL" 'DD-MM-YYYY'

# AT-6: Shared-context existence check — stops if shared-context.md missing
require_regex "AT-6: checks shared-context.md existence" "$SKILL" 'shared-context\.md.*(not exist|does not exist|missing)|exist.*shared-context\.md'
require_text "AT-6: tells user to run /buildit-project-bootstrap" "$SKILL" '/buildit-project-bootstrap'

# --- Worktree working directory (AT-WT-*) ---
require_regex "AT-WT-1: .scratch/ files stay in the project root in worktree mode" "$SKILL" '`\.scratch/`.*stay.*project root'

# --- ## Branch contract (AT-BR-*) ---
line_of() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1 || true; }
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
S5=$(awk '/^### 5\./{f=1} /^## End of skill/{f=0} f' "$SKILL")
if grep -qF -- '`## Branch`' <<<"$S5"; then ok "AT-BR-2: step 5 keys the row with ## Branch"; else fail "AT-BR-2: step 5 must key the row with ## Branch"; fi
if grep -qF -- 'git branch --show-current' <<<"$S5"; then fail "AT-BR-2: step 5 must not read git branch --show-current"; else ok "AT-BR-2: step 5 does not read git branch --show-current"; fi
if grep -qE -- 'after the worktree' <<<"$S5"; then ok "AT-BR-2: step 5 runs after the worktree exists"; else fail "AT-BR-2: step 5 must state it runs after the worktree exists"; fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
