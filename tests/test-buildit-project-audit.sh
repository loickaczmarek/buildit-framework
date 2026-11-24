#!/usr/bin/env bash
# Structural tests for the buildit-project-audit skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-project-audit/SKILL.md"

# AT-1: Canonical structure — frontmatter fields checked by test-skills-invariants.sh
# Here we check numbered step headings exist
require_regex "AT-1: has numbered step headings" "$SKILL" '### [0-9]+\.'

# AT-3: Accepts optional scope argument
require_regex "AT-3: scope argument handling" "$SKILL" '[Ss]cope.*argument|argument.*[Ss]cope'
# Hotspot analysis subagent when no scope provided
require_regex "AT-3: hotspot analysis when no scope" "$SKILL" '[Hh]otspot'
require_regex "AT-3: git churn in hotspot analysis" "$SKILL" 'git log.*name-only|churn'

# AT-4: 6 validate dimensions referenced
require_text "AT-4: dimension — Correctness" "$SKILL" "Correctness"
require_text "AT-4: dimension — Performance" "$SKILL" "Performance"
require_text "AT-4: dimension — Security" "$SKILL" "Security"
require_text "AT-4: dimension — Style" "$SKILL" "Style"
require_regex "AT-4: dimension — Test coverage" "$SKILL" '[Tt]est coverage'
require_regex "AT-4: dimension — Craft principles" "$SKILL" '[Cc]raft principles'

# AT-5: Architecture, documentation gaps, config/setup health
require_regex "AT-5: architecture dimension" "$SKILL" '[Aa]rchitecture|[Cc]oupling|[Cc]ohesion'
require_regex "AT-5: documentation gaps dimension" "$SKILL" '[Dd]ocumentation.*gap'
require_regex "AT-5: config/setup health dimension" "$SKILL" '[Cc]onfig.*health|[Ss]etup.*health|[Cc]onfig/setup'

# AT-6: Draft report in .scratch/audits/
require_regex "AT-6: report output in .scratch/audits/" "$SKILL" '\.scratch/audits/[^ ]*audit-issues\.md'

# AT-7: Independent critique subagent
require_regex "AT-7: critique by independent subagent" "$SKILL" '[Cc]ritique.*subagent|subagent.*[Cc]ritique|[Ii]ndependent.*critique|critique.*independent'

# AT-8: Critique findings incorporated
require_regex "AT-8: critique incorporated into final report" "$SKILL" '[Ii]ncorporat|[Cc]ritique.*integrat'

# AT-9: References craft-principles.md by path (no inline duplication)
require_text "AT-9: references craft-principles.md by path" "$SKILL" "craft-principles.md"
# Must not duplicate the DRY/KISS/YAGNI definitions inline
require_absent "AT-9: no inline DRY definition" "$SKILL" 'Every piece of knowledge or logic has a single'
require_absent "AT-9: no inline KISS definition" "$SKILL" 'Prefer the simplest solution that correctly solves'
require_absent "AT-9: no inline YAGNI definition" "$SKILL" 'Do not implement functionality until it is actually'

# AT-10: Clear boundary with buildit-project-bootstrap
require_regex "AT-10: distinguishes from bootstrap" "$SKILL" 'bootstrap'

# AT-12: Environment detection (Claude mode vs Generic mode)
require_regex "AT-12: Claude mode detection" "$SKILL" '[Cc]laude.*mode|mode.*[Cc]laude'
require_regex "AT-12: Generic mode detection" "$SKILL" '[Gg]eneric.*mode|mode.*[Gg]eneric'

# AT-13: Prerequisite check for shared-context.md
require_text "AT-13: prerequisite check for shared-context.md" "$SKILL" "shared-context.md"
require_regex "AT-13: guard for missing shared-context" "$SKILL" 'not found|does not exist|not exist'

# --- Pipeline restructure assertions ---

# AT-P1: 3 parallel category subagents
require_regex "AT-P1: launches 3 parallel category subagents" "$SKILL" '[Ll]aunch.*3.*parallel|3.*parallel.*subagent|parallel.*category.*subagent'
require_regex "AT-P1: single message with multiple Agent tool calls" "$SKILL" 'single message.*Agent|multiple Agent tool'

# AT-P2: Per-category critique subagent
require_regex "AT-P2: critique runs per category" "$SKILL" '[Cc]ritique.*subagent.*category|per-category.*critique|critique.*for that category'

# AT-P3: Critique receives only its category findings
require_regex "AT-P3: critique scoped to category findings only" "$SKILL" '[Oo]nly.*findings.*from.*category|ONLY.*findings.*from|only.*that category'

# AT-P4: Progressive presentation
require_regex "AT-P4: progressive presentation of findings" "$SKILL" '[Pp]rogressive|present.*as each.*categor|present.*immediately'

# AT-P6: Early write permission trigger before subagents
require_regex "AT-P6: early write permission before subagents" "$SKILL" '[Ww]rite.*permission|permission.*prompt.*early|placeholder.*header.*before.*launch|early.*permission'

# AT-P8: Frontmatter description reflects parallel pipeline
require_regex "AT-P8: frontmatter description mentions parallel" "$SKILL" '^description:.*parallel'

# AT-P9: Existing assertions still pass (covered by AT-1 through AT-13 above)

# --- Calibration assertions ---

# AT-C1: Severity criteria defined (Critical/High/Medium/Low) with evidence requirements
require_text "AT-C1: severity level — Critical" "$SKILL" "Critical"
require_text "AT-C1: severity level — High" "$SKILL" "High"
require_text "AT-C1: severity level — Medium" "$SKILL" "Medium"
require_text "AT-C1: severity level — Low" "$SKILL" "Low"
require_regex "AT-C1: severity criteria section" "$SKILL" '[Ss]everity [Cc]riteria'
require_regex "AT-C1: evidence requirements" "$SKILL" '[Ee]vidence.*require|require.*[Ee]vidence'

# AT-C2: Critical requires execution trace; High requires file:line — downgrade without evidence
require_regex "AT-C2: critical requires execution trace" "$SKILL" '[Cc]ritical.*execution trace|execution trace.*[Cc]ritical'
require_regex "AT-C2: high requires file:line" "$SKILL" '[Hh]igh.*file:line|file:line.*[Hh]igh'
require_regex "AT-C2: downgrade findings lacking evidence" "$SKILL" '[Dd]owngrade.*lack.*evidence|lack.*evidence.*[Dd]owngrade|downgrade.*without.*evidence'

# AT-C3: Cross-cutting execution trace subagent after category subagents
require_regex "AT-C3: execution trace subagent" "$SKILL" '[Ee]xecution [Tt]race.*subagent|subagent.*[Ee]xecution [Tt]race'
require_regex "AT-C3: cross-file interaction focus" "$SKILL" '[Cc]ross-file|implicit dependenc|order-of-operations|mock-masked'

# AT-C4: Execution trace receives already-found findings
require_regex "AT-C4: receives existing findings" "$SKILL" 'already-found|already.found findings|existing findings|avoid duplication'

# AT-C5: Calibration subagent normalizes severity, cannot add findings
require_regex "AT-C5: calibration subagent" "$SKILL" '[Cc]alibration.*subagent|subagent.*[Cc]alibration'
require_regex "AT-C5: receives all findings" "$SKILL" 'receives.*[Aa][Ll][Ll].*findings|ALL findings|all findings'
require_regex "AT-C5: cannot add new findings" "$SKILL" '[Cc]annot add|CANNOT add|must not add|cannot introduce'
require_regex "AT-C5: can downgrade or escalate" "$SKILL" '[Dd]owngrade.*escalat|escalat.*[Dd]owngrade|downgrade or escalate|escalate or downgrade'

# AT-C6: Calibration section in report template
require_regex "AT-C6: calibration section in report" "$SKILL" '## Calibration|Calibration.*section'

# AT-C7: Frontmatter description reflects calibration/execution trace
require_regex "AT-C7: frontmatter mentions calibration" "$SKILL" '^description:.*calibration'
require_regex "AT-C7: frontmatter mentions execution trace" "$SKILL" '^description:.*execution.trace|^description:.*cross-cutting'

# AT-C8: Both copies in sync
SKILL_CLAUDE=".claude/skills/buildit-project-audit/SKILL.md"
if [[ -f "$SKILL_CLAUDE" ]]; then
  if diff -q "$SKILL" "$SKILL_CLAUDE" >/dev/null 2>&1; then
    ok "AT-C8: skills/ and .claude/skills/ copies are in sync"
  else
    fail "AT-C8: skills/ and .claude/skills/ copies differ"
  fi
else
  fail "AT-C8: .claude/skills/ copy missing"
fi

# AT-C9: Design spec exists
SPEC="docs/buildit/specs/2026-10-19-audit-calibration.md"
if [[ -f "$SPEC" ]]; then
  ok "AT-C9: design spec exists"
  require_regex "AT-C9: spec covers severity criteria" "$SPEC" '[Ss]everity.*criteria|criteria.*[Ss]everity'
  require_regex "AT-C9: spec covers execution trace" "$SPEC" '[Ee]xecution [Tt]race'
  require_regex "AT-C9: spec covers calibration" "$SPEC" '[Cc]alibration'
else
  fail "AT-C9: design spec missing — docs/buildit/specs/2026-10-19-audit-calibration.md"
fi


# --- Neutral subagent isolation (AT-I1 through AT-I5) ---

ISO_HEADING='## Subagent selection and workflow isolation'
ISO_SECTION=$(section_body "$SKILL" "$ISO_HEADING")

require_text "AT-I1: isolation section present" "$SKILL" "$ISO_HEADING"
if grep -qF -- 'general-purpose' <<<"$ISO_SECTION"; then ok "AT-I1b: general-purpose agent required"; else fail "AT-I1b: general-purpose not required in isolation section"; fi
if grep -qF -- 'Isolation preamble' <<<"$ISO_SECTION"; then ok "AT-I1c: named Isolation preamble block"; else fail "AT-I1c: Isolation preamble block missing"; fi

PREAMBLE_COUNT=$(grep -c -- 'Remain a neutral execution agent' "$SKILL" || true)
if [[ "$PREAMBLE_COUNT" -eq 1 ]]; then ok "AT-I2: preamble defined exactly once"; else fail "AT-I2: preamble must appear exactly once (found $PREAMBLE_COUNT)"; fi

if grep -qE -- '[Dd]o not invoke any skill or agent' <<<"$ISO_SECTION"; then ok "AT-I3: preamble bans skills and agents"; else fail "AT-I3: ban wording missing"; fi

for term in hotspot category critique 'execution trace' calibration; do
  if grep -qiF -- "$term" <<<"$ISO_SECTION"; then ok "AT-I4: isolation section covers $term subagent"; else fail "AT-I4: isolation section does not cover $term subagent"; fi
done

if grep -qE -- 'default unspeciali[sz]ed subagent' <<<"$ISO_SECTION" && grep -qiE -- 'warn' <<<"$ISO_SECTION"; then
  ok "AT-I5: fallback to default unspecialised subagent with user warning"
else
  fail "AT-I5: fallback (default unspecialised subagent + warning) missing"
fi

# Hotspot fallback scans detected source directories (audit #25)
require_absent "AT-F1: no skills-first fallback" "$SKILL" 'full `skills/` directory \(or `src/` if present\)'
require_text "AT-F1: fallback scans detected source directories" "$SKILL" 'source directories detected from the repository layout'
require_text "AT-F1: fallback exclusions" "$SKILL" 'excluding `.scratch/`, documentation, vendored and generated directories'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
