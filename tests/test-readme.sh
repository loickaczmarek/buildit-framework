#!/usr/bin/env bash
# Structural tests for README.md — factual accuracy and documentation sections.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

README="README.md"

# Section from a heading line (exact prefix) to the next heading of the same
# level, ignoring headings inside fenced code blocks (``` or ~~~).
md_section() { # file, start-prefix, end-prefix
  awk -v s="$2" -v e="$3" '
    /^(```|~~~)/ { fence = !fence }
    !f && index($0, s) == 1 { f = 1; print; next }
    f && !fence && index($0, e) == 1 { exit }
    f' "$1"
}
in_section() { # label, text, fixed pattern
  if grep -qF -- "$3" <<<"$2"; then ok "$1"; else fail "$1 — pattern not found in section: '$3'"; fi
}
in_section_i() { # label, text, case-insensitive regex
  if grep -qiE -- "$3" <<<"$2"; then ok "$1"; else fail "$1 — regex not found in section: '$3'"; fi
}

# AT-R1: no reference to the deleted feature-run design spec
require_absent "AT-R1: no reference to deleted feature-run design spec" "$README" '2026-09-08-buildit-feature-run-design\.md'

# AT-R2: skill count matches skills/ directories, internal skill noted
N=$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
require_text "AT-R2: README states $N skills" "$README" "$N skills"
require_regex "AT-R2: README notes the internal skill" "$README" "$N skills \\([0-9]+ user-facing \\+ the internal \`buildit-worktree\`\\)"

# AT-R3: Project configuration section
CONFIG=$(md_section "$README" '## Project configuration' '## ')
if [[ -n "$CONFIG" ]]; then ok "AT-R3: Project configuration section exists"; else fail "AT-R3: Project configuration section missing"; fi
for key in '## Test command' '## Base branch' '## Task synchronization' '## Synchronization method' '## Synchronization tag'; do
  in_section "AT-R3: Project configuration documents $key" "$CONFIG" "$key"
done
in_section_i "AT-R3: unconfigured is not the same as disabled" "$CONFIG" 'unconfigured, not disabled|unconfigured is not (the same as )?disabled'
in_section_i "AT-R3: bans secrets" "$CONFIG" 'secret'
in_section "AT-R3: example file" "$CONFIG" '```markdown'

# AT-R4: Plan files section
PLAN_FILES=$(md_section "$README" '## Plan files' '## ')
if [[ -n "$PLAN_FILES" ]]; then ok "AT-R4: Plan files section exists"; else fail "AT-R4: Plan files section missing"; fi
for p in 'plan.md' 'task-{name}.md' 'todo' 'in-progress' 'done' 'Readiness' '## Synchronization' 'Link:' 'Pending:' 'buildit-feature-run' 'buildit-feature-discover' 'buildit-plan'; do
  in_section "AT-R4: Plan files section mentions $p" "$PLAN_FILES" "$p"
done
for sk in buildit-plan buildit-feature-discover buildit-feature-run; do
  RS=$(md_section "$README" "### \`$sk\`" '---')
  in_section "AT-R4: $sk section points to Plan files" "$RS" '(#plan-files)'
done

# AT-R5: buildit-worktree inside the skills list under an Internal subheading
SKILLS=$(md_section "$README" '## Skills' '## ')
if grep -qE -- '^(#+ |\*\*)Internal' <<<"$SKILLS" && grep -qF -- '### `buildit-worktree`' <<<"$SKILLS"; then
  ok "AT-R5: buildit-worktree listed in Skills under an Internal subheading"
else
  fail "AT-R5: buildit-worktree must sit in the Skills section under an Internal subheading"
fi
require_absent "AT-R5: no stray (internal) heading outside the skills list" "$README" '^### `buildit-worktree` \(internal\)'
require_absent "AT-R5: Manual flow skills is not a ### heading" "$README" '^### Manual flow skills'

# AT-R6: manual-flow diagram loop border aligned in a single column
MANUAL=$(md_section "$README" '## Manual flow' '## ')
if python3 -I - "$MANUAL" <<'PY'
import sys, unicodedata
def width(text):  # display columns: wide/fullwidth chars (e.g. emoji) take 2
    return sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in text)
lines = sys.argv[1].splitlines()
start = next(i for i, l in enumerate(lines) if '◄' in l)
end = next(i for i, l in enumerate(lines) if '┘' in l)
cols = {width(l.rstrip()) for l in lines[start:end + 1]}
sys.exit(0 if len(cols) == 1 else 1)
PY
then ok "AT-R6: manual-flow loop border aligned"; else fail "AT-R6: manual-flow loop border misaligned"; fi

# AT-R7: Running tests part
TESTS=$(md_section "$README" '## Running tests' '## ')
in_section "AT-R7: Running tests documents run-all" "$TESTS" 'bash tests/run-all.sh'
in_section "AT-R7: Running tests documents assertions helper" "$TESTS" 'tests/lib/assertions.sh'
in_section_i "AT-R7: Running tests documents content-assertion convention" "$TESTS" 'content.assertion'

# AT-R8: validate and ship descriptions reflect staged diff, base branch, staging guard
VALIDATE=$(md_section "$README" '### `buildit-feature-validate`' '---')
in_section "AT-R8: validate mentions staged diff" "$VALIDATE" '--cached --merge-base'
in_section "AT-R8: validate mentions base branch" "$VALIDATE" 'Base branch'
in_section_i "AT-R8: validate mentions staging guard" "$VALIDATE" 'staging guard'
SHIP=$(md_section "$README" '### `buildit-feature-ship`' '---')
in_section "AT-R8: ship mentions staged diff" "$SHIP" '--cached --merge-base'
in_section "AT-R8: ship mentions base branch" "$SHIP" 'Base branch'

# AT-R9: each skill heading and each top-level section appears exactly once
# (a duplicated block left two contradicting ship sections in the README)
count_outside_fences() { # file, exact line
  awk -v l="$2" '/^(```|~~~)/ { fence = !fence } !fence && $0 == l { n++ } END { print n + 0 }' "$1"
}
for d in skills/*/; do
  sk=$(basename "$d")
  n=$(count_outside_fences "$README" "### \`$sk\`")
  if [[ "$n" -eq 1 ]]; then ok "AT-R9: ### \`$sk\` appears once"; else fail "AT-R9: ### \`$sk\` must appear exactly once (found $n)"; fi
done
while IFS= read -r h; do
  n=$(count_outside_fences "$README" "$h")
  if [[ "$n" -eq 1 ]]; then ok "AT-R9: '$h' appears once"; else fail "AT-R9: '$h' must appear exactly once (found $n)"; fi
done < <(awk '/^(```|~~~)/ { fence = !fence } !fence && /^## /' "$README" | sort -u)
n=$(grep -c '^\*\*Manual flow skills\*\*' "$README" || true)
if [[ "$n" -eq 1 ]]; then ok "AT-R9: Manual flow skills block appears once"; else fail "AT-R9: Manual flow skills block must appear exactly once (found $n)"; fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
