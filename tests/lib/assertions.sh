#!/usr/bin/env bash
# Shared assertion helpers for the buildit skill test suite.
# Source this file at the top of each test file.

PASS=0
FAIL=0

ok() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

require_file() {
  if [[ -f "$1" ]]; then ok "file exists: $1"; else fail "file missing: $1"; fi
}

require_text() {
  local label="$1" file="$2" pattern="$3"
  if grep -qF -- "$pattern" "$file" 2>/dev/null; then
    ok "$label"
  else
    fail "$label — pattern not found: '$pattern'"
  fi
}

require_regex() {
  local label="$1" file="$2" pattern="$3"
  if grep -qE -- "$pattern" "$file" 2>/dev/null; then
    ok "$label"
  else
    fail "$label — regex not found: '$pattern'"
  fi
}

require_absent() {
  local label="$1" file="$2" pattern="$3"
  if grep -qE -- "$pattern" "$file" 2>/dev/null; then
    fail "$label — pattern must be absent but was found: '$pattern'"
  else
    ok "$label"
  fi
}
