#!/usr/bin/env bash
# Structural tests for the buildit-feature-validate skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-validate/SKILL.md"

# AT-1: Evaluates on 6 dimensions — correctness, performance, security, style, test coverage, craft principles
REVIEW=$(section "$SKILL" '### 3. Review phase')
in_text "AT-1: review announces 6 dimensions" "$REVIEW" 'Evaluate on these 6 dimensions'
DIM_ROWS=$(grep -cE '^\| \*\*[^*]+\*\* \|' <<<"$REVIEW" || true)
[[ "$DIM_ROWS" -eq 6 ]] && ok "AT-1: dimension table has exactly 6 rows" || fail "AT-1: dimension table must have 6 rows (got $DIM_ROWS)"
for dim in Correctness Performance Security Style 'Test coverage' 'Craft principles'; do
  in_text "AT-1: dimension — $dim" "$REVIEW" "| **$dim** |"
done

# AT-2: Routes to /buildit-feature-build on NO-GO
require_text "AT-2: routes to /buildit-feature-build on NO-GO" "$SKILL" '/buildit-feature-build'

# AT-3: Reads shared-context constraints before reviewing
require_text "AT-3: reads shared-context Constraints section" "$SKILL" 'Constraints discovered'

# AT-4: Craft-principles dimension includes DRY, KISS, YAGNI
CRAFT_ROW=$(grep -F '| **Craft principles** |' <<<"$REVIEW" || true)
for p in DRY KISS YAGNI; do in_text "AT-4: craft-principles dimension references $p" "$CRAFT_ROW" "$p"; done

# AT-5: Craft-principles dimension references the guideline file
in_text "AT-5: craft-principles dimension references craft-principles.md" "$CRAFT_ROW" 'craft-principles.md'

# AT-6: Validate runs the test suite before the review phase
L_TESTS=$(line_of "$SKILL" '### 2b. Run test suite'); L_REVIEW=$(line_of "$SKILL" '### 3. Review phase')
[[ -n "$L_TESTS" && -n "$L_REVIEW" && "$L_TESTS" -lt "$L_REVIEW" ]] && ok "AT-6: test suite step precedes the review phase" || fail "AT-6: ### 2b. Run test suite must precede ### 3. Review phase"

# AT-7/AT-8: a test failure skips review and acceptance and takes the NO-GO path (which sets to-fix)
TESTS=$(section "$SKILL" '### 2b. Run test suite')
in_text "AT-8: test failure skips review and acceptance" "$TESTS" 'If any test fails, the verdict is **FAIL (tests)**: skip the review and acceptance phases'
in_text "AT-7: test failure goes to the NO-GO/FAIL path" "$TESTS" 'go directly to "If NO-GO or FAIL"'
in_text "AT-7: NO-GO/FAIL path sets to-fix" "$(section "$SKILL" '## If NO-GO or FAIL')" 'to-fix'

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
PRE=$(section "$SKILL" '### 0b. Prerequisite check')
in_text "AT-12: prerequisite check tests shared-context.md existence" "$PRE" 'If `.scratch/shared-context.md` does not exist, stop'
in_text "AT-12: prerequisite check points to /buildit-project-bootstrap" "$PRE" 'run `/buildit-project-bootstrap`'


# --- Neutral subagent isolation for the §5a config-update subagent (AT-I1 through AT-I4) ---

SECTION_5A=$(section_body "$SKILL" '### 5a.')
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
require_text "AT-STAGE-1: staging guard runs git status --porcelain" "$SKILL" 'status --porcelain'
require_regex "AT-STAGE-2: NO-GO listing unstaged/untracked files" "$SKILL" 'NO-GO.*(list|listing).*(untracked|unstaged)|(untracked|unstaged).*NO-GO.*(list|listing)'
GUARD_LINE=$(grep -nF -- 'status --porcelain' "$SKILL" | head -1 | cut -d: -f1 || true)
DIFF_LINE=$(grep -nF -- 'git diff --cached --merge-base' "$SKILL" | head -1 | cut -d: -f1 || true)
if [[ -n "$GUARD_LINE" && -n "$DIFF_LINE" && "$GUARD_LINE" -lt "$DIFF_LINE" ]]; then
  ok "AT-STAGE-3: staging guard runs before the review diff"
else
  fail "AT-STAGE-3: staging guard must appear before the review diff"
fi

# --- Worktree working directory (AT-WT-*) ---
require_text "AT-WT-1: git commands target the worktree" "$SKILL" 'git -C <worktree-path>'
require_regex "AT-WT-2: .scratch/ and config.md are read from the project root" "$SKILL" '`\.scratch/` and `\.buildit/config\.md`.*project root'

# --- Worktree working directory (AT-WD-*) ---
WD_LINE=$(grep -E -- '^\*\*Working directory:\*\*' "$SKILL" || true)
if grep -qE -- '[Tt]est.*worktree as (the )?working directory|cd <worktree-path>' <<<"$WD_LINE"; then
  ok "AT-WD-1: tests run with the worktree as working directory"
else
  fail "AT-WD-1: Working directory note must run the test command in the worktree"
fi
WD_2B=$TESTS
if grep -qE -- 'worktree' <<<"$WD_2B"; then ok "AT-WD-1: test detection and run happen in the worktree"; else fail "AT-WD-1: step 2b must evaluate markers and run tests in the worktree"; fi
require_absent "AT-WD-amend: no commit --amend in validate" "$SKILL" 'commit --amend'
WD_5A=$(section "$SKILL" '### 5a.')
for pat in 'inside the worktree in worktree mode, in the project root otherwise' 'git [-C <worktree-path>] add' '<rules-file>'; do
  if grep -qF -- "$pat" <<<"$WD_5A"; then ok "AT-WD-3: 5a contains '$pat'"; else fail "AT-WD-3: 5a must contain '$pat'"; fi
done
WD_2A=$(section "$SKILL" '### 2a.')
if grep -qF -- 'git [-C <worktree-path>] status --porcelain' <<<"$WD_2A"; then ok "AT-WD-4: guard runs status in the worktree"; else fail "AT-WD-4: guard must use git [-C <worktree-path>] status --porcelain"; fi
if grep -qE -- '5a.*staged|staged.*5a' <<<"$WD_2A"; then ok "AT-WD-4: guard notes 5a stages its own edits"; else fail "AT-WD-4: guard must state step 5a edits are staged"; fi

# --- Staging contract (AT-SC-*) ---
GUARD_HEAD=$(grep -nE -- '^### .*Staging guard' "$SKILL" | head -1 | cut -d: -f1 || true)
TESTS_HEAD=$(grep -nE -- '^### .*Run test suite' "$SKILL" | head -1 | cut -d: -f1 || true)
if [[ -n "$GUARD_HEAD" && -n "$TESTS_HEAD" && -n "$GUARD_LINE" && "$GUARD_HEAD" -lt "$TESTS_HEAD" && "$GUARD_LINE" -lt "$TESTS_HEAD" ]]; then
  ok "AT-SC-3: staging guard runs before the test suite"
else
  fail "AT-SC-3: staging guard must be a step placed before the test suite"
fi
C5_SEC=$(section "$SKILL" '### 5c.')
in_text_re "AT-SC-4: test failure routes to the NO-GO path" "$TESTS" '[Tt]est fail.*If NO-GO or FAIL|If NO-GO or FAIL.*test fail'
absent_in_text "AT-SC-4: no test-failure shortcut that stops before bookkeeping" "$TESTS" 'write a "Problems to fix" section.*and stop'
in_text_re "AT-SC-4: 5a issue list includes failing tests" "$SECTION_5A" 'issues.*(test suite|failing tests)'
in_text "AT-SC-4: 5c counts only NO-GO cycle headings" "$C5_SEC" '`### NO-GO cycle`'
require_absent "AT-SC-4: 5c no longer counts every Progress entry" "$SKILL" 'Count the number of existing entries in the "Progress" section'
in_text_re "AT-SC-4: Progress entry records tests" "$C5_SEC" '^- Tests:'
require_regex "AT-SC-5: base-branch failure writes ## Last error" "$SKILL" '`## Last error`.*base branch|base branch.*`## Last error`|Base branch.*`## Last error`'
require_regex "AT-SC-5: step 1 clears a stale ## Last error" "$SKILL" '`## Last error` section.*remove'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
