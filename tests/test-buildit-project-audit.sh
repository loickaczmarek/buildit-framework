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

# AT-6: Draft report in .scratch/
require_regex "AT-6: report output in .scratch/" "$SKILL" '\.scratch/.*audit-issues\.md'

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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
