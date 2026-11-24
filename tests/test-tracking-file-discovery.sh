#!/usr/bin/env bash
# Structural tests for the tracking file discovery rule shared by the phase skills
# (build, validate, ship, run) and the audit report location.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

PHASES=(
  "skills/buildit-feature-build/SKILL.md"
  "skills/buildit-feature-validate/SKILL.md"
  "skills/buildit-feature-ship/SKILL.md"
  "skills/buildit-feature-run/SKILL.md"
)
VALIDATE="skills/buildit-feature-validate/SKILL.md"
AUDIT="skills/buildit-project-audit/SKILL.md"

# AT-1: the rule content (reference copy: build). Presence in every phase skill and the
# identity of each copy are checked in test-cross-skill-contracts.sh (named blocks).
REFERENCE="$(named_block "${PHASES[0]}" '**Tracking file discovery rule**')"

check_rule() { in_text "$1" "$REFERENCE" "$2"; }
check_rule "AT-1: candidates need a ## Status heading" '`## Status` heading'
for s in to-build building to-validate validating to-fix to-ship; do
  check_rule "AT-1: feature status $s listed" "\`$s\`"
done
check_rule "AT-1: named lookup matches the exact suffix" '`DD-MM-YYYY-<feature-name>.md`'
check_rule "AT-1: named lookup rejects substring matches" 'never a substring match'
check_rule "AT-1: several matches → ask" 'ask which one to use'

# AT-2: shared-context.md, audit reports and plan/ can never be selected
check_rule "AT-2: top level of .scratch/ only" 'Search only the top level of the project root `.scratch/`'
check_rule "AT-2: shared-context.md excluded" '`shared-context.md`'
check_rule "AT-2: audit reports excluded" '`.scratch/audits/`'
check_rule "AT-2: plan files excluded" '`.scratch/plan/`'
for f in "${PHASES[@]}"; do
  require_absent "AT-2: no 'most recent' pick in $f" "$f" '[Mm]ost recent'
  require_absent "AT-2: no substring glob lookup in $f" "$f" '\*\[?feature-name\]?\*'
done

# AT-3: the audit writes its report under .scratch/audits/
require_text "AT-3: audit report under .scratch/audits/" "$AUDIT" '.scratch/audits/DD-MM-YYYY-audit-issues.md'
require_absent "AT-3: no audit report at the .scratch/ top level" "$AUDIT" '\.scratch/DD-MM-YYYY-audit-issues\.md'

# AT-4: validate stops when the status is not to-validate, before setting validating
require_text "AT-4: validate status guard" "$VALIDATE" 'buildit-feature-validate expects `to-validate`'
guard_line="$(line_of "$VALIDATE" 'buildit-feature-validate expects `to-validate`')"
set_line="$(line_of "$VALIDATE" 'Set the status to `validating`')"
if [[ -n "$guard_line" && -n "$set_line" && "$guard_line" -lt "$set_line" ]]; then
  ok "AT-4: guard precedes setting status to validating"
else
  fail "AT-4: guard must precede 'Set the status to \`validating\`'"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
