#!/usr/bin/env bash
# Structural tests for the buildit-project-bootstrap skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-project-bootstrap/SKILL.md"

# AT-1: Scans the guidelines directory
require_regex "AT-1: scans guidelines directory" "$SKILL" '\.buildit/guidelines'

# AT-2: Detects Claude mode vs generic mode
require_regex "AT-2: detects Claude mode" "$SKILL" '[Cc]laude.*mode|mode.*[Cc]laude'
require_regex "AT-2: detects generic mode" "$SKILL" '[Gg]eneric.*mode|mode.*[Gg]eneric'

# AT-3: Produces a bootstrap commit
require_regex "AT-3: produces a bootstrap commit" "$SKILL" 'git commit'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
