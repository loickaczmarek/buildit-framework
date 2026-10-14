#!/usr/bin/env bash
# Cross-skill consistency tests for generic test runner detection.
# Verifies that bootstrap and validate reference the same ecosystem markers.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

BOOTSTRAP="skills/buildit-project-bootstrap/SKILL.md"
VALIDATE="skills/buildit-feature-validate/SKILL.md"

# Ecosystems that both skills must reference
ECOSYSTEMS=(
  "tests/run-all.sh"
  "package.json"
  "pom.xml"
  "build.gradle"
  "pyproject.toml"
  "Makefile"
)

for eco in "${ECOSYSTEMS[@]}"; do
  require_text "bootstrap references $eco" "$BOOTSTRAP" "$eco"
  require_text "validate references $eco" "$VALIDATE" "$eco"
done

# Both skills must reference .buildit/config.md
require_text "bootstrap references .buildit/config.md" "$BOOTSTRAP" ".buildit/config.md"
require_text "validate references .buildit/config.md" "$VALIDATE" ".buildit/config.md"

# Validate must have a two-tier detection structure (config first, fallback second)
require_regex "validate: config-first tier" "$VALIDATE" '[Cc]onfigured command|[Cc]onfig.*first|[Tt]ier 1'
require_regex "validate: fallback tier" "$VALIDATE" '[Ff]allback|[Tt]ier 2|[Ee]cosystem.*detection'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
