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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
