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

# AT-4: Path guard present — mentions "project root" and "web tool"
require_regex "AT-4: path guard mentions 'project root'" "$SKILL" 'project root'
require_regex "AT-4: path guard mentions 'web tool'" "$SKILL" 'web tool'

# AT-5: Step 2b present
require_regex "AT-5: step 2b present" "$SKILL" '2b'

# AT-6: Claude-mode .claude/settings.json check present
require_text "AT-6: .claude/settings.json check present" "$SKILL" '.claude/settings.json'

# AT-7: Offer-to-create prompt present
require_text "AT-7: offer-to-create prompt present" "$SKILL" 'Autonomy settings missing'

# AT-8: Broad Bash(cd *) absent from the template
require_absent "AT-8: broad Bash(cd *) absent from template" "$SKILL" 'Bash\(cd \\\*\)'

# AT-9: Ecosystem detection covers all 6 markers
require_text "AT-9: ecosystem detection — tests/run-all.sh" "$SKILL" 'tests/run-all.sh'
require_text "AT-9: ecosystem detection — package.json" "$SKILL" 'package.json'
require_text "AT-9: ecosystem detection — pom.xml" "$SKILL" 'pom.xml'
require_regex "AT-9: ecosystem detection — build.gradle" "$SKILL" 'build\.gradle'
require_text "AT-9: ecosystem detection — pyproject.toml" "$SKILL" 'pyproject.toml'
require_text "AT-9: ecosystem detection — Makefile" "$SKILL" 'Makefile'

# AT-10: User confirmation prompt for detected test command
require_regex "AT-10: user confirmation prompt for test command" "$SKILL" '[Cc]onfirm|[Cc]orrect'

# AT-11: Stores test command in .buildit/config.md
require_text "AT-11: stores test command in .buildit/config.md" "$SKILL" '.buildit/config.md'

# AT-SYNC-12: optional task synchronization configuration
require_text "AT-SYNC-12: optional sync step" "$SKILL" '### 6b. Configure task synchronization (optional)'
TPL=$(awk 'index($0,"# Project Configuration")==1{f=1} f&&index($0,"~~~")==1{exit} f' "$SKILL")
for h in '## Task synchronization' '## Synchronization method' '## Synchronization tag'; do
  if grep -qF -- "$h" <<<"$TPL"; then ok "AT-SYNC-12: config template has $h"; else fail "AT-SYNC-12: config template lacks $h"; fi
done
require_text "AT-SYNC-12: default tag technical" "$SKILL" 'default `technical`'
require_text "AT-SYNC-12: unconfigured not disabled" "$SKILL" 'unconfigured, not disabled'
require_regex "AT-SYNC-12: no secrets" "$SKILL" 'never secrets|no secrets|other secrets'

# --- Base branch detection (AT-BASE-*) ---
require_text "AT-BASE-1: detects base branch from origin/HEAD" "$SKILL" 'git symbolic-ref refs/remotes/origin/HEAD'
require_regex "AT-BASE-1: falls back to main" "$SKILL" 'falls? back to `main`|defaults? to `main`'
require_text "AT-BASE-2: proposes detected base branch for confirmation" "$SKILL" 'Detected base branch'
if grep -qF -- '## Base branch' <<<"$TPL"; then ok "AT-BASE-3: config template has ## Base branch"; else fail "AT-BASE-3: config template lacks ## Base branch"; fi
require_text "AT-BASE-4: language-framework.md documents ## Base branch" ".buildit/guidelines/language-framework.md" '## Base branch'

# --- No hardcoded main diff range in any SKILL.md (AT-BASE-5) ---
if grep -lE -- 'main\.\.' skills/*/SKILL.md >/dev/null 2>&1; then
  fail "AT-BASE-5: a SKILL.md still hardcodes main... or main..HEAD: $(grep -lE -- 'main\.\.' skills/*/SKILL.md | tr '\n' ' ')"
else
  ok "AT-BASE-5: no SKILL.md hardcodes main... or main..HEAD"
fi

# --- Staging contract (AT-SC-*) ---
RULES_TPL=$(mktemp); trap 'rm -f "$RULES_TPL"' EXIT
awk '/^`<rules-file>`:/{f=1;next} /^`<guidelines-dir>\/team-practices\.md`:/{f=0} f' "$SKILL" > "$RULES_TPL"
require_regex "AT-SC-2: rules-file template contains the staging rule" "$RULES_TPL" 'to-validate.*stage.*git status|stage.*git status.*to-validate'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
