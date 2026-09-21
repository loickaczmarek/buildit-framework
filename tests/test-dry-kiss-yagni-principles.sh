#!/usr/bin/env bash
# Cross-skill invariant tests for the DRY/KISS/YAGNI principles integration.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

BUILD_SKILL="skills/buildit-feature-build/SKILL.md"
VALIDATE_SKILL="skills/buildit-feature-validate/SKILL.md"
GUIDELINE="skills/../.buildit/guidelines/craft-principles.md"
GUIDELINE_DIR=".buildit/guidelines/craft-principles.md"

# AT-3: Definitions live only in craft-principles.md — skill files must not contain the definitions
# (only a reference/pointer). The canonical definitions use specific wording: "Don't Repeat Yourself",
# "Keep It Simple", "You Aren't Gonna Need It".
require_absent "AT-3: build skill must not define DRY (Don't Repeat Yourself)" "$BUILD_SKILL" "Don.t Repeat Yourself"
require_absent "AT-3: build skill must not define KISS (Keep It Simple)" "$BUILD_SKILL" "Keep It Simple"
require_absent "AT-3: build skill must not define YAGNI (You Aren.t Gonna Need It)" "$BUILD_SKILL" "You Aren.t Gonna Need It"
require_absent "AT-3: validate skill must not define DRY (Don't Repeat Yourself)" "$VALIDATE_SKILL" "Don.t Repeat Yourself"
require_absent "AT-3: validate skill must not define KISS (Keep It Simple)" "$VALIDATE_SKILL" "Keep It Simple"
require_absent "AT-3: validate skill must not define YAGNI (You Aren.t Gonna Need It)" "$VALIDATE_SKILL" "You Aren.t Gonna Need It"

# AT-4: Both skills reference craft-principles.md with the same filename
require_text "AT-4: build skill references craft-principles.md" "$BUILD_SKILL" 'craft-principles.md'
require_text "AT-4: validate skill references craft-principles.md" "$VALIDATE_SKILL" 'craft-principles.md'

# AT-5: craft-principles.md exists in .buildit/guidelines/
require_file "$GUIDELINE_DIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
