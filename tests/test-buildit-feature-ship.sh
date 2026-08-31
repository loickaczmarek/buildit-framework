#!/usr/bin/env bash
# Structural tests for the buildit-feature-ship skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-ship/SKILL.md"

# AT-1: Cleans shared-context.md at close (Merge readiness + API sections)
require_text "AT-1: cleans Merge readiness section" "$SKILL" 'Merge readiness'
require_regex "AT-1: removes API & Contracts section for branch" "$SKILL" 'API & Contracts'

# AT-2: Migrates durable constraints to guidelines
require_regex "AT-2: migrates durable constraints" "$SKILL" '(durable|migrate|Migrate)'

# AT-3: Does NOT push or create the PR (explicit in skill)
require_regex "AT-3: does not push or create PR" "$SKILL" '(Push|push).*(manual|yours|not)'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
