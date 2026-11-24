#!/usr/bin/env bash
# Asserts that every .buildit/config.md consumer reads a heading's value only
# within that heading (Config value rule), so an empty heading never yields the
# next heading as its value (audit findings #6, #16).

set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

PHRASE='read only within that heading (stop at the next heading); a line starting with `#` is never a value'
GUIDELINE=".buildit/guidelines/language-framework.md"
README="README.md"
CONSUMERS=(
  buildit-feature-validate
  buildit-feature-ship
  buildit-feature-run
  buildit-feature-discover
  buildit-project-bootstrap
  buildit-plan
)

# AT-1: the rule is defined once in the guideline
require_text "AT-1: guideline names the Config value rule" "$GUIDELINE" "**Config value rule:**"
require_text "AT-1: guideline states the boundary phrase" "$GUIDELINE" "$PHRASE"
require_text "AT-1: guideline treats an empty value as absent" "$GUIDELINE" "an empty value is treated exactly like an absent one"

# AT-1/AT-4: every consumer restates the phrase and cites the guideline
for skill in "${CONSUMERS[@]}"; do
  file="skills/$skill/SKILL.md"
  require_text "AT-4: $skill states the boundary phrase" "$file" "$PHRASE"
  require_text "AT-1: $skill cites the Config value rule" "$file" "Config value rule"
done
require_text "AT-4: README states the boundary phrase" "$README" "$PHRASE"

# AT-4: no unbounded read remains — every line describing the read carries the boundary
for file in "$GUIDELINE" "$README" "${CONSUMERS[@]/#/skills/}"; do
  [[ "$file" == skills/* ]] && file="$file/SKILL.md"
  offending=$(grep -nF 'first non-empty, non-comment line' "$file" | grep -vF 'read only within that heading' || true)
  if [[ -z "$offending" ]]; then
    ok "AT-4: no unbounded config read in $file"
  else
    fail "AT-4: unbounded config read in $file — $offending"
  fi
done

# AT-2: empty values fall back
VALIDATE="skills/buildit-feature-validate/SKILL.md"
SHIP="skills/buildit-feature-ship/SKILL.md"
require_regex "AT-2: validate Tier 1 sends an empty value to Tier 2" "$VALIDATE" 'Tier 1.*[Ee]mpty.*Tier 2'
require_regex "AT-2: validate Tier 2 triggers on an empty heading" "$VALIDATE" 'Tier 2.*heading empty'
require_regex "AT-2: validate 2c defaults an empty base branch to main" "$VALIDATE" '`## Base branch`.*empty.*defaults to `main`'
require_regex "AT-2: ship defaults an empty base branch to main" "$SHIP" '`## Base branch`.*empty.*defaults to `main`'
require_text "AT-2: guideline sends an empty test command to ecosystem detection" "$GUIDELINE" 'An empty `## Test command` falls back to ecosystem detection'

# AT-3: bootstrap fast path still resolves the test command and base branch
BOOTSTRAP="skills/buildit-project-bootstrap/SKILL.md"
require_regex "AT-3: bootstrap fast path still runs 4e and 4f" "$BOOTSTRAP" '^- Fast →.*still run 4e and 4f'
require_regex "AT-3: bootstrap fast path preserves existing values" "$BOOTSTRAP" '^- Fast →.*preserve'
require_absent "AT-3: bootstrap fast path no longer skips step 4 wholesale" "$BOOTSTRAP" '^- Fast → skip steps 3 and 4, go directly to step 5'
require_text "AT-3: bootstrap step 8 preserves untouched config headings" "$BOOTSTRAP" 'If `.buildit/config.md` already exists, update only the headings whose values changed'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
