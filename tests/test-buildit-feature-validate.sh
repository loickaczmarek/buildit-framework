#!/usr/bin/env bash
# Structural tests for the buildit-feature-validate skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-validate/SKILL.md"

# AT-1: Evaluates on 5 dimensions — correctness, performance, security, style, coverage
require_regex "AT-1: dimension — correctness" "$SKILL" '[Cc]orrectness'
require_regex "AT-1: dimension — performance" "$SKILL" '[Pp]erformance'
require_regex "AT-1: dimension — security" "$SKILL" '[Ss]ecurity'
require_regex "AT-1: dimension — style" "$SKILL" '[Ss]tyle'
require_regex "AT-1: dimension — test coverage" "$SKILL" '[Cc]overage'

# AT-2: Routes to /buildit-feature-build on NO-GO
require_text "AT-2: routes to /buildit-feature-build on NO-GO" "$SKILL" '/buildit-feature-build'

# AT-3: Reads shared-context constraints before reviewing
require_text "AT-3: reads shared-context Constraints section" "$SKILL" 'Constraints discovered'

# AT-4: Craft-principles dimension includes DRY, KISS, YAGNI
require_text "AT-4: validate dimension references DRY" "$SKILL" 'DRY'
require_text "AT-4: validate dimension references KISS" "$SKILL" 'KISS'
require_text "AT-4: validate dimension references YAGNI" "$SKILL" 'YAGNI'

# AT-5: Craft-principles dimension references the guideline file
require_text "AT-5: validate references craft-principles.md" "$SKILL" 'craft-principles.md'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
