#!/usr/bin/env bash
# Structural tests for the buildit-feature-validate skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-validate/SKILL.md"

# AT-1: Evaluates on 5 dimensions — correctness, performance, security, style, coverage
require_regex "AT-1: dimension — correctness" "$SKILL" '[Cc]orrectness'
require_regex "AT-1: dimension — performance" "$SKILL" '[Pp]erformance'
require_regex "AT-1: dimension — security" "$SKILL" '[Ss]ecurity'
require_regex "AT-1: dimension — style" "$SKILL" '[Ss]tyle'
require_regex "AT-1: dimension — test coverage" "$SKILL" '[Cc]overage'

# AT-2: Routes to /buildit-feature-build on NO-GO
require_text "AT-2: routes to /buildit-feature-build on NO-GO" "$SKILL" '/buildit-feature-build'

# AT-3: Reads shared-context constraints before reviewing
require_text "AT-3: reads shared-context Constraints section" "$SKILL" 'Constraints discovered'

# AT-4: Craft-principles dimension includes DRY, KISS, YAGNI
require_text "AT-4: validate dimension references DRY" "$SKILL" 'DRY'
require_text "AT-4: validate dimension references KISS" "$SKILL" 'KISS'
require_text "AT-4: validate dimension references YAGNI" "$SKILL" 'YAGNI'

# AT-5: Craft-principles dimension references the guideline file
require_text "AT-5: validate references craft-principles.md" "$SKILL" 'craft-principles.md'

# AT-6: Validate runs the test suite before the review phase
require_regex "AT-6: mentions running test suite" "$SKILL" '[Tt]est suite|[Rr]un.*tests'

# AT-7: On test failure, status is set to to-fix and review does not proceed
require_text "AT-7: sets status to to-fix on test failure" "$SKILL" 'to-fix'

# AT-8: Does not proceed to review if tests fail
require_regex "AT-8: skips review on test failure" "$SKILL" '([Dd]o not proceed|[Ss]kip.*review|[Ss]top)'

# AT-9: Validate reads .buildit/config.md as primary test command source
require_text "AT-9: reads .buildit/config.md for test command" "$SKILL" '.buildit/config.md'

# AT-10: Fallback heuristic covers all 6 ecosystems
require_text "AT-10: fallback — tests/run-all.sh" "$SKILL" 'tests/run-all.sh'
require_text "AT-10: fallback — package.json" "$SKILL" 'package.json'
require_text "AT-10: fallback — pom.xml" "$SKILL" 'pom.xml'
require_regex "AT-10: fallback — build.gradle" "$SKILL" 'build\.gradle'
require_text "AT-10: fallback — pyproject.toml" "$SKILL" 'pyproject.toml'
require_text "AT-10: fallback — Makefile" "$SKILL" 'Makefile'

# AT-11: Warns when no test runner and no config detected
require_regex "AT-11: warns when no detection" "$SKILL" '[Nn]o test runner detected|[Nn]o configured command'

# AT-12: Shared-context existence check — stops if shared-context.md missing
require_regex "AT-12: checks shared-context.md existence" "$SKILL" 'shared-context\.md.*(not exist|does not exist|missing)|exist.*shared-context\.md'
require_text "AT-12: tells user to run /buildit-project-bootstrap" "$SKILL" '/buildit-project-bootstrap'


# --- Neutral subagent isolation for the §5a config-update subagent (AT-I1 through AT-I4) ---

SECTION_5A=$(awk '/^### 5a\./ {f=1; next} f && /^### 5b\./ {exit} f' "$SKILL")
if grep -qF -- 'general-purpose' <<<"$SECTION_5A"; then ok "AT-I1: §5a requires general-purpose agent"; else fail "AT-I1: §5a does not require general-purpose"; fi
if grep -qF -- 'Remain a neutral execution agent' <<<"$SECTION_5A"; then ok "AT-I2: §5a includes the isolation preamble"; else fail "AT-I2: §5a isolation preamble missing"; fi
if grep -qE -- '[Dd]o not invoke any skill or agent' <<<"$SECTION_5A"; then ok "AT-I3: §5a preamble bans skills and agents"; else fail "AT-I3: §5a ban wording missing"; fi
if grep -qE -- 'default unspeciali[sz]ed subagent' <<<"$SECTION_5A" && grep -qiE -- 'warn' <<<"$SECTION_5A"; then
  ok "AT-I4: §5a fallback to default unspecialised subagent with user warning"
else
  fail "AT-I4: §5a fallback missing"
fi

# --- Base branch and staged review diff (AT-BASE-*) ---
require_text "AT-BASE-1: review diff covers staged work vs base branch" "$SKILL" 'git diff --cached --merge-base <base-branch>'
require_text "AT-BASE-2: git < 2.30 fallback" "$SKILL" 'git diff --cached $(git merge-base <base-branch> HEAD)'
require_text "AT-BASE-2: fallback names git 2.30" "$SKILL" '2.30'
require_absent "AT-BASE-3: no hardcoded main...HEAD" "$SKILL" 'main\.\.\.HEAD|main\.\.HEAD'
require_text "AT-BASE-4: reads ## Base branch" "$SKILL" '## Base branch'
require_regex "AT-BASE-4: defaults to main" "$SKILL" 'defaults? to `main`|falls? back to `main`'

# --- Staging guard (AT-STAGE-*) ---
require_text "AT-STAGE-1: staging guard runs git status --porcelain" "$SKILL" 'git status --porcelain'
require_regex "AT-STAGE-2: NO-GO listing unstaged/untracked files" "$SKILL" 'NO-GO.*(list|listing).*(untracked|unstaged)|(untracked|unstaged).*NO-GO.*(list|listing)'
GUARD_LINE=$(grep -nF -- 'git status --porcelain' "$SKILL" | head -1 | cut -d: -f1 || true)
DIFF_LINE=$(grep -nF -- 'git diff --cached --merge-base' "$SKILL" | head -1 | cut -d: -f1 || true)
if [[ -n "$GUARD_LINE" && -n "$DIFF_LINE" && "$GUARD_LINE" -lt "$DIFF_LINE" ]]; then
  ok "AT-STAGE-3: staging guard runs before the review diff"
else
  fail "AT-STAGE-3: staging guard must appear before the review diff"
fi

# --- Worktree working directory (AT-WT-*) ---
require_text "AT-WT-1: git commands target the worktree" "$SKILL" 'git -C <worktree-path>'
require_regex "AT-WT-2: .scratch/ and config.md are read from the project root" "$SKILL" '`\.scratch/` and `\.buildit/config\.md`.*project root'

# --- Staging contract (AT-SC-*) ---
GUARD_HEAD=$(grep -nE -- '^### .*Staging guard' "$SKILL" | head -1 | cut -d: -f1 || true)
TESTS_HEAD=$(grep -nE -- '^### .*Run test suite' "$SKILL" | head -1 | cut -d: -f1 || true)
if [[ -n "$GUARD_HEAD" && -n "$TESTS_HEAD" && -n "$GUARD_LINE" && "$GUARD_HEAD" -lt "$TESTS_HEAD" && "$GUARD_LINE" -lt "$TESTS_HEAD" ]]; then
  ok "AT-SC-3: staging guard runs before the test suite"
else
  fail "AT-SC-3: staging guard must be a step placed before the test suite"
fi
TESTS_SEC=$(mktemp); C5_SEC=$(mktemp); trap 'rm -f "$TESTS_SEC" "$C5_SEC"' EXIT
awk '/^### .*Run test suite/{f=1;print;next} /^### /{f=0} f' "$SKILL" > "$TESTS_SEC"
awk '/^### 5c\./{f=1;print;next} /^## /{f=0} f' "$SKILL" > "$C5_SEC"
require_regex "AT-SC-4: test failure routes to the NO-GO path" "$TESTS_SEC" '[Tt]est fail.*If NO-GO or FAIL|If NO-GO or FAIL.*test fail'
require_absent "AT-SC-4: no test-failure shortcut that stops before bookkeeping" "$TESTS_SEC" 'write a "Problems to fix" section.*and stop'
require_regex "AT-SC-4: 5a issue list includes failing tests" "$SKILL" 'issues.*(test suite|failing tests)'
require_text "AT-SC-4: 5c counts only NO-GO cycle headings" "$C5_SEC" '`### NO-GO cycle`'
require_absent "AT-SC-4: 5c no longer counts every Progress entry" "$SKILL" 'Count the number of existing entries in the "Progress" section'
require_regex "AT-SC-4: Progress entry records tests" "$C5_SEC" '^- Tests:'
require_regex "AT-SC-5: base-branch failure writes ## Last error" "$SKILL" '`## Last error`.*base branch|base branch.*`## Last error`|Base branch.*`## Last error`'
require_regex "AT-SC-5: step 1 clears a stale ## Last error" "$SKILL" '`## Last error` section.*remove'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
