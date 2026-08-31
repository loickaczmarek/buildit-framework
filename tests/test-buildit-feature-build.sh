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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
