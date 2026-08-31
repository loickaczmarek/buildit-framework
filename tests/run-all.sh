#!/usr/bin/env bash
# Runs all test-*.sh files in the tests/ directory and aggregates results.
# Exits non-zero if any test file fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
ANY_FAILURE=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  echo "=== $(basename "$test_file") ==="
  if output=$(bash "$test_file" 2>&1); then
    status=0
  else
    status=$?
    ANY_FAILURE=1
  fi
  echo "$output"
  pass=$(echo "$output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo 0)
  failed=$(echo "$output" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || echo 0)
  TOTAL_PASS=$((TOTAL_PASS + pass))
  TOTAL_FAIL=$((TOTAL_FAIL + failed))
  [[ $status -ne 0 ]] && ANY_FAILURE=1
  echo ""
done

echo "=============================="
echo "Total: $TOTAL_PASS passed, $TOTAL_FAIL failed"

[[ $ANY_FAILURE -eq 0 && $TOTAL_FAIL -eq 0 ]]
