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
TPL=$(fenced_block "$SKILL" '# Project Configuration')
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
RULES_TPL=$(section_body "$SKILL" '`<rules-file>`:' '`<guidelines-dir>/team-practices.md`:')
in_text_re "AT-SC-2: rules-file template contains the staging rule" "$RULES_TPL" 'to-validate.*stage.*git status|stage.*git status.*to-validate'

# --- Bootstrap templates audit 24-11-2026 (AT-TB-*) ---
README="README.md"
RUN_SKILL="skills/buildit-feature-run/SKILL.md"
S2=$(section "$SKILL" '### 2. Detect workflow configuration files' '### 2b.')
TP_TPL=$(section "$SKILL" '`<guidelines-dir>/team-practices.md`:' '`<guidelines-dir>/language-framework.md`')
CP_TPL=$(section "$SKILL" '`<guidelines-dir>/craft-principles.md`:' '`.scratch/shared-context.md`:')
S9=$(section "$SKILL" '### 9. Commit' '## End of skill')
END=$(section "$SKILL" '## End of skill')

# AT-TB-1: craft-principles.md detected, templated, and indexed by the rules file
in_text "AT-TB-1: step 2 detects craft-principles.md" "$S2" '<guidelines-dir>/craft-principles.md'
if [[ -n "$CP_TPL" ]]; then ok "AT-TB-1: craft-principles.md template present"; else fail "AT-TB-1: craft-principles.md template missing"; fi
for p in DRY KISS YAGNI; do in_text "AT-TB-1: craft-principles template covers $p" "$CP_TPL" "## $p"; done
in_text "AT-TB-1: rules-file template indexes craft-principles.md" "$RULES_TPL" '.buildit/guidelines/craft-principles.md'
require_text "AT-TB-1: this repo's rules file indexes craft-principles.md" ".claude/CLAUDE.md" '.buildit/guidelines/craft-principles.md'

# AT-TB-2: 6 review dimensions and the full tracking-file section list
in_text "AT-TB-2: team-practices template has the Craft principles dimension" "$TP_TPL" '- Craft principles:'
# The template body is fenced: unwrap it with fenced_block, then scope the list with section_body.
DIMS=$(section_body <(fenced_block "$SKILL" '# Team Practices') 'Mandatory evaluation dimensions:' | grep -c '^- ' || true)
if [[ "$DIMS" -eq 6 ]]; then ok "AT-TB-2: 6 review dimensions"; else fail "AT-TB-2: expected 6 review dimensions, found $DIMS"; fi
in_text "AT-TB-2: full tracking-file section list" "$TP_TPL" 'Tracking file sections: Status · Branch · Worktree path · Goal · Acceptance Tests · Plan · Progress · Problems to fix · Last error'

# AT-TB-3: anchored cd patterns, honest security note, one worktree permission string
for f in "$SKILL" "$README"; do
  require_text "AT-TB-3: $f has Bash(cd <project-root>)" "$f" '"Bash(cd <project-root>)"'
  require_text "AT-TB-3: $f has Bash(cd <project-root>/*)" "$f" '"Bash(cd <project-root>/*)"'
  require_absent "AT-TB-3: $f has no unanchored Bash(cd <project-root>*)" "$f" 'Bash\(cd <project-root>\*\)'
  require_absent "AT-TB-3: $f does not claim the cd patterns block escape" "$f" 'None allows|parent-directory escape'
  require_regex "AT-TB-3: $f states the allowlist is not a security boundary" "$f" 'not a (security )?(boundary|sandbox)'
done
require_regex "AT-TB-3: README says chained subcommands are matched separately" "$README" 'each (`&&`|&&) subcommand|each subcommand'
require_absent "AT-TB-3: bootstrap leaves the && rationale to the README" "$SKILL" 'each (`&&`|&&) subcommand|each subcommand'
require_text "AT-TB-3: bootstrap points to the README settings section" "$SKILL" 'README section "settings.json permission file (Claude mode only)"'
require_text "AT-TB-3: bootstrap keeps its guidelines migration logic" "$SKILL" 'remove them first (legacy format)'
require_absent "AT-TB-3: run uses no '&& *' worktree permission variant" "$RUN_SKILL" 'Bash\(cd \*/\.worktrees/\* && \*\)'
require_absent "AT-TB-3: run names no permission rule (harness detail lives in the README)" "$RUN_SKILL" 'Bash\(cd '
require_absent "AT-TB-3: run leaves the && rationale to the README" "$RUN_SKILL" 'each (`&&`|&&) subcommand|each subcommand'

# AT-TB-4: explicit staging and gitignored settings.local.json
absent_in_text "AT-TB-4: no directory-wide staging (Claude)" "$S9" 'git add \.claude/ \.buildit/ \.scratch/'
absent_in_text "AT-TB-4: no directory-wide staging (Generic)" "$S9" 'git add \.agents/guidelines/project-rules\.md \.buildit/ \.scratch/'
absent_in_text "AT-TB-4: no git add of a bare directory" "$S9" 'git add[^`]* (\.claude|\.buildit|\.scratch)/( |$)'
in_text "AT-TB-4: stages .claude/settings.json explicitly" "$S9" '.claude/settings.json'
in_text "AT-TB-4: stages craft-principles.md explicitly" "$S9" '.buildit/guidelines/craft-principles.md'
in_text "AT-TB-4: ensures settings.local.json is gitignored" "$S9" '.claude/settings.local.json'
in_text "AT-TB-4: stages .gitignore" "$S9" 'git add .gitignore'
require_regex "AT-TB-4: this repo ignores .claude/settings.local.json" ".gitignore" '^\.claude/settings\.local\.json$'

# AT-SCL-*: shared-context.md is gitignored local state, never committed by bootstrap
S9N=$(normalize <<<"$S9")
absent_in_text "AT-SCL-1: step 9 never stages .scratch/shared-context.md (Claude and Generic)" "$S9" 'git add [^`]*\.scratch/shared-context\.md'
in_text "AT-SCL-1: step 9 gitignores .scratch/shared-context.md when absent (both modes)" "$S9N" 'Both modes: if `.gitignore` does not already list `.scratch/shared-context.md`, append it'
in_text "AT-SCL-1: step 9 untracks an already-tracked shared-context.md" "$S9N" 'git rm --cached --quiet --ignore-unmatch .scratch/shared-context.md'
same "AT-SCL-1: .gitignore is staged in both modes (one git add .gitignore under Both modes)" "$(fenced_block "$SKILL" '# Claude mode:' | section_body /dev/stdin '# Both modes:' | grep -c '^git add \.gitignore$' || true)" 1
absent_in_text "AT-SCL-5: rules-file template drops the closing-commit cleanup rule" "$RULES_TPL" 'Cleaning shared-context\.md mandatory in the closing commit'
in_text "AT-SCL-5: rules-file template says shared-context.md is local, untracked" "$RULES_TPL" 'shared-context.md is local, untracked state'
in_text "AT-SCL-5: rules-file template migrates durable entries at ship time" "$RULES_TPL" 'migrate into the appropriate guideline at ship time'
SC_TPL=$(fenced_block "$SKILL" '# Shared Context')
for h in '## API & Contracts modified' '## Constraints discovered' '## Decisions & Conventions' '## Merge readiness'; do
  in_text "AT-SCL-2: shared-context template keeps '$h'" "$SC_TPL" "$h"
done

# AT-TB-5: no "workflow v2", closing message recommends run, description has no "audit"
require_absent "AT-TB-5: bootstrap has no 'workflow v2'" "$SKILL" 'workflow v2'
require_absent "AT-TB-5: README has no 'workflow v2'" "$README" 'workflow v2'
in_text "AT-TB-5: closing message recommends /buildit-feature-run" "$END" '/buildit-feature-run'
if grep -E '^description:' "$SKILL" | grep -qi 'audit'; then fail "AT-TB-5: description must not use 'audit'"; else ok "AT-TB-5: description does not use 'audit'"; fi

# AT-TB-8: Progress line carries the NO-GO cycle count and the Last error convention
in_text "AT-TB-8: template states the ### NO-GO cycle count" "$TP_TPL" '`### NO-GO cycle`'
in_text "AT-TB-8: template states the ## Last error convention" "$TP_TPL" '`## Last error`'

# AT-TB-9: Coring summary matches the steps actually run
CORING=$(grep -F -- '**Coring summary:**' "$SKILL" || true)
in_text_re "AT-TB-9: coring summary covers the full path 4a–4f" "$CORING" 'full path[^;]*4a–4f'
in_text_re "AT-TB-9: coring summary covers the fast path 4e and 4f only" "$CORING" 'fast path[^;]*4e and 4f'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
