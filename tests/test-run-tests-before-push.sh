#!/usr/bin/env bash
# Structural tests for the run-tests-before-push feature.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

HOOK="scripts/hooks/pre-push"
INSTALLER="scripts/install-hooks.sh"
PRACTICES=".buildit/guidelines/team-practices.md"

# AT-1: pre-push hook exists and is executable
if [[ -f "$HOOK" ]]; then ok "AT-1: scripts/hooks/pre-push exists"; else fail "AT-1: scripts/hooks/pre-push missing"; fi
if [[ -x "$HOOK" ]]; then ok "AT-1: pre-push hook is executable"; else fail "AT-1: pre-push hook is not executable"; fi

# AT-2: pre-push hook references run-all.sh
require_text "AT-2: hook calls run-all.sh" "$HOOK" "run-all.sh"

# AT-5: installer script exists and is executable
if [[ -f "$INSTALLER" ]]; then ok "AT-5: scripts/install-hooks.sh exists"; else fail "AT-5: scripts/install-hooks.sh missing"; fi
if [[ -x "$INSTALLER" ]]; then ok "AT-5: installer is executable"; else fail "AT-5: installer is not executable"; fi

# AT-5: installer references pre-push
require_text "AT-5: installer references pre-push" "$INSTALLER" "pre-push"

# AT-6: installer uses cp (idempotent overwrite)
require_text "AT-6: installer uses cp for idempotent install" "$INSTALLER" "cp "

# AT-7: team-practices.md documents install-hooks.sh
require_text "AT-7: team-practices.md mentions install-hooks.sh" "$PRACTICES" "install-hooks.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
