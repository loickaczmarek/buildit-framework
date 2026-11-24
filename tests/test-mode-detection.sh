#!/usr/bin/env bash
# Structural tests for the Operating mode rule: one agent-identity rule, defined in the
# team-practices guideline and copied verbatim into every skill that detects the mode.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

GUIDELINE=".buildit/guidelines/team-practices.md"
SKILLS=(
  "skills/buildit-feature-discover/SKILL.md"
  "skills/buildit-feature-run/SKILL.md"
  "skills/buildit-plan/SKILL.md"
  "skills/buildit-feature-validate/SKILL.md"
  "skills/buildit-feature-ship/SKILL.md"
  "skills/buildit-project-audit/SKILL.md"
  "skills/buildit-project-bootstrap/SKILL.md"
)
BOOTSTRAP="skills/buildit-project-bootstrap/SKILL.md"
README="README.md"
HEADING='**Operating mode rule**'

# Prints the rule block: from the heading line to the first blank line.
extract_rule() {
  awk -v h="$HEADING" '$0 == h {on=1} on && /^$/ {exit} on {print}' "$1"
}

# AT-1: one rule, defined in the guideline and copied byte-identically into each skill
REFERENCE="$(extract_rule "$GUIDELINE")"
if [[ -n "$REFERENCE" ]]; then ok "AT-1: rule block present in $GUIDELINE"; else fail "AT-1: rule block missing in $GUIDELINE"; fi
for f in "$GUIDELINE" "${SKILLS[@]}"; do
  count="$(grep -cxF -- "$HEADING" "$f" || true)"
  if [[ "$count" -eq 1 ]]; then ok "AT-1: rule heading appears once in $f"; else fail "AT-1: rule heading appears $count times in $f (expected 1)"; fi
done
for f in "${SKILLS[@]}"; do
  rule="$(extract_rule "$f")"
  if [[ -n "$rule" && "$rule" == "$REFERENCE" ]]; then
    ok "AT-1: rule block identical to the guideline copy in $f"
  else
    fail "AT-1: rule block missing or differs from the guideline copy in $f"
  fi
done

check_rule() {
  local label="$1" pattern="$2"
  if grep -qF -- "$pattern" <<<"$REFERENCE"; then ok "$label"; else fail "$label — not in rule: '$pattern'"; fi
}
check_rule "AT-1: mode is the agent identity" 'identity of the agent'
check_rule "AT-1: Claude mode value" '`MODE` = `claude`'
check_rule "AT-1: Generic mode value" '`MODE` = `generic`'
check_rule "AT-1: Claude rules file" '`.claude/CLAUDE.md`'
check_rule "AT-1: Generic rules file" '`.agents/guidelines/project-rules.md`'
check_rule "AT-1: Claude skills directory" '`.claude/skills/`'
check_rule "AT-1: Generic skills directory" '`.agents/skills/`'
check_rule "AT-1: never inferred from directories" 'Never infer the mode from the presence of `.claude/` or `.agents/`'
check_rule "AT-2: mode never persisted" 'never persisted'

# AT-2: bootstrap's switched confirmation is scoped to its own run, and not persisted
require_text "AT-2: switched answer applies only to the generated kit" "$BOOTSTRAP" 'applies only to the kit this run generates'
require_text "AT-2: other skills apply the rule for the running agent" "$BOOTSTRAP" 'every other skill applies the Operating mode rule for the agent that runs it'
require_absent "AT-2: no mode heading in bootstrap's config template" "$BOOTSTRAP" '^## (Operating )?[Mm]ode$'

# AT-3 / AT-4: no directory-existence mode check anywhere
FILES=(skills/*/SKILL.md .buildit/guidelines/*.md "$README")
for pattern in 'ls .claude/' '`.claude/` directory exists' 'check for a `.claude/` directory'; do
  offenders="$(grep -lF -- "$pattern" "${FILES[@]}" || true)"
  if [[ -z "$offenders" ]]; then
    ok "AT-4: no '$pattern' mode check"
  else
    fail "AT-4: '$pattern' found in: $(echo "$offenders" | tr '\n' ' ')"
  fi
done

# AT-3: README defines MODE by agent identity
mode_line="$(grep -F -- '- **`MODE`**' "$README" || true)"
if [[ -n "$mode_line" ]] && grep -qF 'identity' <<<"$mode_line"; then
  ok "AT-3: README MODE definition is agent identity"
else
  fail "AT-3: README MODE definition must describe agent identity"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
