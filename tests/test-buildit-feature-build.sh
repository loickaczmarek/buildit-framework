#!/usr/bin/env bash
# Structural tests for the buildit-feature-build skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-build/SKILL.md"

# AT-1: Detects fix mode via "Problems to fix" section
require_text "AT-1: fix mode triggered by Problems to fix section" "$SKILL" 'Problems to fix'

# AT-2: TDD mode writes failing tests before implementing
require_regex "AT-2: TDD mode writes failing tests first" "$SKILL" '(fail|failing).*(test|impl)'

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
require_regex "AT-9: checks shared-context.md existence" "$SKILL" 'shared-context\.md.*(not exist|does not exist|missing)|exist.*shared-context\.md'
require_text "AT-9: tells user to run /buildit-project-bootstrap" "$SKILL" '/buildit-project-bootstrap'

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
STEP5=$(mktemp); trap 'rm -f "$STEP5"' EXIT
awk '/^### 5\./{f=1} /^## End of skill/{f=0} f' "$SKILL" > "$STEP5"
require_text "AT-SC-1: step 5 stages feature files" "$STEP5" 'git [-C <worktree-path>] add'
require_text "AT-SC-1: step 5 checks status --porcelain" "$STEP5" 'status --porcelain'
require_regex "AT-SC-1: step 5 excludes .scratch/ from the check" "$STEP5" '`\.scratch/`'
ADD_L=$(grep -nF -- 'git [-C <worktree-path>] add' "$STEP5" | head -1 | cut -d: -f1 || true)
POR_L=$(grep -nF -- 'status --porcelain' "$STEP5" | head -1 | cut -d: -f1 || true)
TOV_L=$(grep -nE -- '[Ss]et the status to `to-validate`' "$STEP5" | head -1 | cut -d: -f1 || true)
if [[ -n "$ADD_L" && -n "$POR_L" && -n "$TOV_L" && "$ADD_L" -lt "$TOV_L" && "$POR_L" -lt "$TOV_L" ]]; then
  ok "AT-SC-1: staging and porcelain check happen before setting to-validate"
else
  fail "AT-SC-1: staging and porcelain check must precede setting to-validate"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
