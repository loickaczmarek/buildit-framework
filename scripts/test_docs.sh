#!/usr/bin/env bash
# Test suite for update-docs acceptance criteria
# All tests must PASS after the documentation update.

PASS=0
FAIL=0
README="README.md"

pass() { echo "PASS: $1"; ((PASS++)); }
fail() { echo "FAIL: $1"; ((FAIL++)); }

# AT1 — Quick start section exists AND appears before Manual flow section
at1_quick_start_line=$(grep -n "## Quick start" "$README" | head -1 | cut -d: -f1)
at1_manual_flow_line=$(grep -n "## Manual flow" "$README" | head -1 | cut -d: -f1)

if [ -z "$at1_quick_start_line" ]; then
  fail "AT1: '## Quick start' section not found in README"
elif [ -z "$at1_manual_flow_line" ]; then
  fail "AT1: '## Manual flow' section not found in README"
elif [ "$at1_quick_start_line" -lt "$at1_manual_flow_line" ]; then
  pass "AT1: '## Quick start' (line $at1_quick_start_line) appears before '## Manual flow' (line $at1_manual_flow_line)"
else
  fail "AT1: '## Quick start' (line $at1_quick_start_line) does NOT appear before '## Manual flow' (line $at1_manual_flow_line)"
fi

# AT2 — No stale references in docs/ (dangling superpowers reference removed, buildit spec present)
stale_ref=$(grep -n "docs/superpowers/specs/2026-08-03-bootstrap-mode-confirmation-design.md" "$README")
if [ -n "$stale_ref" ]; then
  fail "AT2: Stale dangling reference to superpowers spec still present in README"
else
  pass "AT2: No stale docs/superpowers reference in README"
fi

# AT2b — docs/ contains only the valid buildit spec
stale_file=$(find docs/ -type f ! -name "2026-09-08-buildit-feature-run-design.md")
if [ -n "$stale_file" ]; then
  fail "AT2b: Unexpected file(s) in docs/: $stale_file"
else
  pass "AT2b: docs/ contains only the expected buildit spec"
fi

# AT3 — README title reflects "buildit" and "workflow"
if grep -qi "^# buildit" "$README"; then
  pass "AT3: README title starts with '# buildit'"
else
  fail "AT3: README title does not start with '# buildit' (found: $(head -1 $README))"
fi

# AT4 — Autonomy configuration section exists
if grep -q "## Autonomy configuration" "$README"; then
  pass "AT4: '## Autonomy configuration' section present in README"
else
  fail "AT4: '## Autonomy configuration' section NOT found in README"
fi

# AT4b — settings.json template shown
if grep -q "settings.json" "$README" && grep -q "allowList\|allowedPaths\|Bash(cd" "$README"; then
  pass "AT4b: settings.json template with cd patterns referenced in README"
else
  fail "AT4b: settings.json template with cd patterns NOT found in README"
fi

# AT5 — --max-cycles configuration guidance exists (beyond just the trigger line)
max_cycles_count=$(grep -c "\-\-max-cycles" "$README")
if [ "$max_cycles_count" -ge 3 ]; then
  pass "AT5: '--max-cycles' mentioned $max_cycles_count times (configuration guidance present)"
else
  fail "AT5: '--max-cycles' only mentioned $max_cycles_count time(s) — configuration guidance insufficient"
fi

# AT5b — default value documented
if grep -q "default.*3\|3.*default" "$README"; then
  pass "AT5b: Default cycle count (3) is documented"
else
  fail "AT5b: Default cycle count not documented"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
