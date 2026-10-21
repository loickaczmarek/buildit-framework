#!/usr/bin/env bash
# Tests for the quote-skill-descriptions feature.
# Validates that all SKILL.md description values are double-quoted,
# deployed copies match source, and YAML frontmatter is valid.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILLS=(
  buildit-feature-build
  buildit-feature-discover
  buildit-feature-run
  buildit-feature-ship
  buildit-feature-start
  buildit-feature-validate
  buildit-project-audit
  buildit-project-bootstrap
  buildit-worktree
)

# --- AT1: All description values in skills/*/SKILL.md are wrapped in double quotes ---

for skill in "${SKILLS[@]}"; do
  src="skills/$skill/SKILL.md"
  require_regex "AT1 $skill: description is double-quoted" "$src" '^description: ".*"$'
done

# --- AT2: All description values in .claude/skills/*/SKILL.md are identical to their skills/ counterpart ---

for skill in "${SKILLS[@]}"; do
  src="skills/$skill/SKILL.md"
  deployed=".claude/skills/$skill/SKILL.md"
  src_desc=$(grep '^description:' "$src" 2>/dev/null || echo "MISSING_SRC")
  deployed_desc=$(grep '^description:' "$deployed" 2>/dev/null || echo "MISSING_DEPLOYED")
  if [[ "$src_desc" == "$deployed_desc" ]]; then
    ok "AT2 $skill: deployed description matches source"
  else
    fail "AT2 $skill: deployed description differs from source"
  fi
done

# --- AT3: Special chars (em dashes, colons, arrows, brackets) are safe inside the quotes ---

for skill in "${SKILLS[@]}"; do
  src="skills/$skill/SKILL.md"
  desc_line=$(grep '^description:' "$src" 2>/dev/null || echo "")
  # Extract the value between the outer double quotes
  quoted_value=$(echo "$desc_line" | sed -n 's/^description: "\(.*\)"$/\1/p')
  if [[ -n "$quoted_value" ]]; then
    # Check there are no unescaped internal double quotes or backslashes that would break YAML
    if echo "$quoted_value" | grep -qE '[^\\]"' 2>/dev/null; then
      fail "AT3 $skill: unescaped double quote inside description"
    else
      ok "AT3 $skill: no unescaped special chars inside quotes"
    fi
  else
    fail "AT3 $skill: could not extract quoted description value"
  fi
done

# --- AT4: Guideline template shows the quoted format ---

require_regex "AT4: guideline template shows quoted description format" \
  ".buildit/guidelines/language-framework.md" \
  'description: ".*"'

# --- AT5: All SKILL.md files parse as valid YAML frontmatter ---

for skill in "${SKILLS[@]}"; do
  src="skills/$skill/SKILL.md"
  # Extract frontmatter: lines between the first and second --- only (skip body content)
  frontmatter=$(awk 'BEGIN{n=0} /^---$/{n++; next} n==1{print} n>=2{exit}' "$src" 2>/dev/null)
  if echo "$frontmatter" | python3 -I -c "import sys, yaml; yaml.safe_load(sys.stdin)" 2>/dev/null; then
    ok "AT5 $skill: YAML frontmatter parses successfully"
  else
    fail "AT5 $skill: YAML frontmatter parse error"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
