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

# --- Repo-root anchoring -----------------------------------------------------
# Every test uses repo-relative paths; anchor to the repo root so the suite
# runs from any working directory (standalone or via run-all.sh).
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

# --- Fence-aware Markdown extractors -------------------------------------------
# A fence opens on a line starting (after optional indentation) with ``` or ~~~
# and closes on the next line starting with the same marker. Lines inside a
# fence are printed as content but never match START/END nor end a section.
_FENCE_AWK='
function fence_step(   m) {
  if (match($0, /^[ \t]*(```|~~~)/)) {
    m = substr($0, RSTART + RLENGTH - 3, 3)
    if (!fence) { fence = m; return 1 }
    if (m == fence) { fence = ""; return 1 }
  }
  return fence != ""
}
function hlevel(s,   n) { n = match(s, /^#+ /) ? RLENGTH - 1 : 0; return n }
'

# section FILE START [END] — from the first line (outside fences) starting with
# START, heading included, to the line before: the first line starting with END
# if END is given; else the next heading of the same or higher level when START
# is a heading; else the next heading of any level.
section() {
  awk -v s="$2" -v e="${3-}" "$_FENCE_AWK"'
    BEGIN { lvl = hlevel(s) }
    { infence = fence_step() }
    !on && !infence && index($0, s) == 1 { on = 1; print; next }
    on && !infence {
      if (e != "") { if (index($0, e) == 1) exit }
      else { h = hlevel($0); if (h && (!lvl || h <= lvl)) exit }
    }
    on { print }
  ' "$1"
}

# section_body FILE START [END] — section without its first line.
section_body() { section "$@" | tail -n +2; }

# named_block FILE HEADING — from the line exactly equal to HEADING (outside
# fences) to the first blank line: the named-rule convention.
named_block() {
  awk -v h="$2" "$_FENCE_AWK"'
    { infence = fence_step() }
    !on && !infence && $0 == h { on = 1 }
    on && /^[ \t]*$/ { exit }
    on { print }
  ' "$1"
}

# fenced_block FILE FIRST — content of the first fenced block whose first
# content line starts with FIRST (fence lines excluded).
fenced_block() {
  awk -v f="$2" "$_FENCE_AWK"'
    { was = fence; infence = fence_step() }
    on && infence && fence == "" { exit }
    on { print; next }
    was != "" && infence && index($0, f) == 1 && prev_open { on = 1; print }
    { prev_open = (was == "" && fence != "") }
  ' "$1"
}

# count_outside_fences FILE EXACT_LINE
count_outside_fences() {
  awk -v l="$2" "$_FENCE_AWK"'
    { infence = fence_step() } !infence && $0 == l { n++ } END { print n + 0 }
  ' "$1"
}

# lines_outside_fences FILE REGEX — lines matching REGEX (awk ERE) outside fences.
lines_outside_fences() {
  awk -v r="$2" "$_FENCE_AWK"'{ infence = fence_step() } !infence && $0 ~ r' "$1"
}

# line_of FILE FIXED [NTH] — line number of the NTH (default 1) line containing FIXED.
line_of() { { grep -nF -- "$2" "$1" || true; } | sed -n "${3:-1}p" | cut -d: -f1; }

# normalize — read stdin, join lines and squeeze whitespace (wrap-insensitive text).
normalize() { tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'; }

# --- Assertions on captured text ---------------------------------------------------
in_text() {
  local label="$1" text="$2" pattern="$3"
  if grep -qF -- "$pattern" <<<"$text"; then ok "$label"; else fail "$label — not found in section: '$pattern'"; fi
}
in_text_re() {
  local label="$1" text="$2" pattern="$3"
  if grep -qE -- "$pattern" <<<"$text"; then ok "$label"; else fail "$label — regex not found in section: '$pattern'"; fi
}
absent_in_text() {
  local label="$1" text="$2" pattern="$3"
  if grep -qE -- "$pattern" <<<"$text"; then fail "$label — must be absent from section: '$pattern'"; else ok "$label"; fi
}
