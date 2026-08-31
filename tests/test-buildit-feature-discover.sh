#!/usr/bin/env bash
# Structural tests for the buildit-feature-discover skill.
# Each test maps to one acceptance criterion from the tracking file.
# Tests pass if the skill content is structurally correct.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL_SRC="skills/buildit-feature-discover/SKILL.md"
SKILL_DEPLOYED=".claude/skills/buildit-feature-discover/SKILL.md"

# AT-1: Skill triggered explicitly — not auto-invoked from feature-start
# Evidence: name in frontmatter is buildit-feature-discover (distinct name, not embedded in feature-start)
require_file "$SKILL_SRC"
require_text "AT-1: frontmatter name is buildit-feature-discover" "$SKILL_SRC" 'name: buildit-feature-discover'
require_text "AT-1: description mentions /buildit-feature-discover" "$SKILL_SRC" 'buildit-feature-discover'

# AT-2: Analysis phase reads shared-context.md, guidelines, and scans project structure
require_text "AT-2: reads shared-context.md" "$SKILL_SRC" 'shared-context.md'
require_regex "AT-2: reads guidelines dir" "$SKILL_SRC" '\.buildit/guidelines'
require_regex "AT-2: scans project structure (ls skills)" "$SKILL_SRC" '(ls|scan|list).*skills'

# AT-3: Asks user about external documentation before posing questions
require_regex "AT-3: asks about external documentation" "$SKILL_SRC" '(documentation|specs|user stories|design doc)'

# AT-4: Questions target functional understanding (problem, users, expected behaviour, success criteria)
require_regex "AT-4: functional questions — problem" "$SKILL_SRC" 'problem'
require_regex "AT-4: functional questions — users" "$SKILL_SRC" 'user'
require_regex "AT-4: functional questions — success criteria" "$SKILL_SRC" 'success'

# AT-5: Synthesis translates functional to technical, anchored in project conventions
require_regex "AT-5: anchors description in conventions" "$SKILL_SRC" '(convention|guideline|pattern)'

# AT-6: Brief contains kebab-case name, technical description, acceptance tests, risks/constraints
require_regex "AT-6: brief has kebab-case name field" "$SKILL_SRC" 'kebab'
require_regex "AT-6: brief has acceptance tests" "$SKILL_SRC" '(Acceptance tests|Tests d.acceptation|\[ \])'
require_regex "AT-6: brief has risks/constraints section" "$SKILL_SRC" '(Risques|Contraintes|Risks|Constraints)'

# AT-7: Brief presented to user for validation before finalised
require_regex "AT-7: validation step before finalising" "$SKILL_SRC" '(valid|confirm|approv)'

# AT-8: Output explicitly proposes /buildit-feature-start [feature-name]
require_text "AT-8: handoff to buildit-feature-start" "$SKILL_SRC" '/buildit-feature-start'

# Dual-location deployment: source and deployed copy must both exist
require_file "$SKILL_DEPLOYED"

# Both files must have identical content
if [[ -f "$SKILL_SRC" && -f "$SKILL_DEPLOYED" ]]; then
  if diff -q "$SKILL_SRC" "$SKILL_DEPLOYED" > /dev/null 2>&1; then
    ok "deployed copy matches source"
  else
    fail "deployed copy differs from source"
  fi
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
