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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
