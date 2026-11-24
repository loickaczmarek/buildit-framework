#!/usr/bin/env bash
# Structural tests for the buildit-feature-build skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-build/SKILL.md"

# AT-1: Detects fix mode via "Problems to fix" section
require_text "AT-1: fix mode triggered by Problems to fix section" "$SKILL" 'Problems to fix'

# AT-2: TDD mode writes failing tests before implementing
in_text_re "AT-2: TDD mode writes failing tests first" "$(section "$SKILL" '### 3a. Write the tests')" 'Tests must fail'

# AT-3: Handoff instruction references /buildit-feature-validate
require_text "AT-3: handoff references /buildit-feature-validate" "$SKILL" '/buildit-feature-validate'

# AT-4: Checks API changes in shared-context before building
require_text "AT-4: reads API & Contracts from shared-context" "$SKILL" 'API & Contracts'

# AT-5: Updates tracking file status to to-validate when done
require_text "AT-5: sets status to to-validate on completion" "$SKILL" 'to-validate'

# AT-6: Craft-principles self-review references DRY, KISS, YAGNI
require_text "AT-6: references DRY" "$SKILL" 'DRY'
require_text "AT-6: references KISS" "$SKILL" 'KISS'
require_text "AT-6: references YAGNI" "$SKILL" 'YAGNI'

# AT-7: Craft-principles self-review references the guideline file
require_text "AT-7: references craft-principles.md" "$SKILL" 'craft-principles.md'

# AT-8: Status guard — rejects unexpected status with warning and confirmation
require_regex "AT-8: guard mentions to-build and to-fix as expected statuses" "$SKILL" 'to-build.*to-fix|to-fix.*to-build'
require_regex "AT-8: guard warns about current status" "$SKILL" '[Cc]urrent status|[Uu]nexpected status|status is'
require_regex "AT-8: guard asks for confirmation" "$SKILL" '[Cc]onfirm|[Cc]ontinue anyway'

# AT-9: Shared-context existence check — stops if shared-context.md missing
PRE=$(section "$SKILL" '### 0. Prerequisite check')
in_text "AT-9: prerequisite check tests shared-context.md existence" "$PRE" 'If `.scratch/shared-context.md` does not exist, stop'
in_text "AT-9: prerequisite check points to /buildit-project-bootstrap" "$PRE" 'run `/buildit-project-bootstrap`'

# --- Worktree working directory (AT-WT-*) ---
require_text "AT-WT-1: git commands target the worktree" "$SKILL" 'git -C <worktree-path>'
require_regex "AT-WT-2: .scratch/ and config.md are read from the project root" "$SKILL" '`\.scratch/` and `\.buildit/config\.md`.*project root'

# --- Worktree working directory (AT-WD-*) ---
WD_LINE=$(grep -E -- '^\*\*Working directory:\*\*' "$SKILL" || true)
if grep -qE -- '[Tt]est.*worktree as (the )?working directory|cd <worktree-path>' <<<"$WD_LINE"; then
  ok "AT-WD-1: tests run with the worktree as working directory"
else
  fail "AT-WD-1: Working directory note must run the test command in the worktree"
fi
require_absent "AT-WD-amend: no commit --amend in build" "$SKILL" 'commit --amend'

# --- Staging contract (AT-SC-*) ---
STEP5=$(section "$SKILL" '### 5.')
in_text "AT-SC-1: step 5 stages feature files" "$STEP5" 'git [-C <worktree-path>] add'
in_text "AT-SC-1: step 5 checks status --porcelain" "$STEP5" 'status --porcelain'
in_text "AT-SC-1: step 5 excludes .scratch/ from the check" "$STEP5" '`.scratch/`'
ADD_L=$(line_of <(echo "$STEP5") 'git [-C <worktree-path>] add')
POR_L=$(line_of <(echo "$STEP5") 'status --porcelain')
TOV_L=$(line_of <(echo "$STEP5") 'et the status to `to-validate`')
if [[ -n "$ADD_L" && -n "$POR_L" && -n "$TOV_L" && "$ADD_L" -lt "$TOV_L" && "$POR_L" -lt "$TOV_L" ]]; then
  ok "AT-SC-1: staging and porcelain check happen before setting to-validate"
else
  fail "AT-SC-1: staging and porcelain check must precede setting to-validate"
fi

# --- <guidelines-dir> definition (AT-GD-*) ---
GD_L=$(grep -nE -- '`<guidelines-dir>` *=' "$SKILL" | head -1 | cut -d: -f1 || true)
S0_L=$(grep -nE -- '^### 0\.' "$SKILL" | head -1 | cut -d: -f1 || true)
S1_L=$(grep -nE -- '^### 1\.' "$SKILL" | head -1 | cut -d: -f1 || true)
if [[ -n "$GD_L" && -n "$S0_L" && -n "$S1_L" && "$S0_L" -lt "$GD_L" && "$GD_L" -lt "$S1_L" ]]; then
  ok "AT-GD-1: <guidelines-dir> is defined in step 0"
else
  fail "AT-GD-1: <guidelines-dir> must be defined in step 0 (def line ${GD_L:-none})"
fi
require_regex "AT-GD-1: <guidelines-dir> resolves to .buildit/guidelines/" "$SKILL" '`<guidelines-dir>` *= *`\.buildit/guidelines/`'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
