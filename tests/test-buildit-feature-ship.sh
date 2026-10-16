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

# AT-4: Ship computes file overlap for each IN_PROGRESS branch via git diff
require_regex "AT-4: per-branch overlap via git diff" "$SKILL" 'git diff main\.\.\.<branch'

# AT-5: Ship instructs to compare touched files between branches dynamically
require_regex "AT-5: dynamic overlap for IN_PROGRESS branches" "$SKILL" 'IN_PROGRESS.*diff|diff.*IN_PROGRESS|each.*branch.*--name-only'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
