#!/usr/bin/env bash
# Cross-skill structural invariants.
# Verifies every skill satisfies the 7 structural invariants.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

# The skill list is every directory under skills/: a new skill is covered without
# editing this file, and a skill directory without SKILL.md is a failure.
SKILLS=()
for d in skills/*/; do SKILLS+=("$(basename "$d")"); done
if [[ ${#SKILLS[@]} -gt 0 ]]; then ok "skill list built from skills/*/ (${#SKILLS[@]} skills)"; else fail "no skill directory found under skills/"; fi

for skill in "${SKILLS[@]}"; do
  src="skills/$skill/SKILL.md"
  deployed=".claude/skills/$skill/SKILL.md"

  require_file "$src"
  require_file "$deployed"

  if [[ -f "$src" && -f "$deployed" ]]; then
    if diff -q "$src" "$deployed" > /dev/null 2>&1; then
      ok "$skill: deployed copy matches source"
    else
      fail "$skill: deployed copy differs from source"
    fi
  fi

  require_regex "$skill: frontmatter name field" "$src" "^name: $skill"
  require_regex "$skill: frontmatter description field" "$src" "^description:"
  require_text "$skill: ## Steps section present" "$src" "## Steps"
  require_text "$skill: ## End of skill section present" "$src" "## End of skill"
done

# Cross-skill invariant: skills that write to shared-context.md mention sequential access.
# Kept explicit: "writes shared-context.md" is a behaviour, not a detectable heading.
WRITERS=(
  buildit-feature-start
  buildit-feature-build
  buildit-feature-ship
)

for skill in "${WRITERS[@]}"; do
  src="skills/$skill/SKILL.md"
  require_regex "$skill: shared-context writer mentions sequential access" "$src" '[Ss]equential access'
done

# Audit 24-11-2026 #34: no pre-buildit command names, no French tokens in tests.
for f in skills/*/SKILL.md README.md .buildit/guidelines/*.md; do
  require_absent "$f: no unprefixed /feature-* command" "$f" '(^|[^-a-z])/feature-'
done
# Accented letters written as byte escapes so this file never matches itself.
FR_RE=$(printf '\xc3\xa9|\xc3\xa8|\xc3\xa0|\xc3\xaa|\xc3\xa7|\xc3\xb9')
for f in tests/*.sh tests/lib/*.sh; do
  require_absent "$f: no French token (accented letter)" "$f" "$FR_RE"
done

# Audit 24-11-2026 #31, #33: one worktree permission string, no "workflow v2" wording.
for f in skills/*/SKILL.md README.md; do
  require_absent "$f: no 'cd */.worktrees/* && *' permission variant" "$f" 'worktrees/\* && \*'
  require_absent "$f: no 'workflow v2' wording" "$f" '[Ww]orkflow v2'
done

# Audit 24-11-2026 #29: team-practices testing lines reflect the current harness.
TEAM_TESTING=$(section .buildit/guidelines/team-practices.md '## Testing')
absent_in_text "team-practices: no 'No automated test framework'" "$TEAM_TESTING" 'No automated test framework'
in_text "team-practices: run-all is the suite entry point" "$TEAM_TESTING" 'tests/run-all.sh'
in_text "team-practices: CI runs the suite" "$TEAM_TESTING" '.github/workflows/tests.yml'
in_text "team-practices: helpers live in tests/lib/assertions.sh" "$TEAM_TESTING" 'tests/lib/assertions.sh'
in_text_re "team-practices: helper list includes require_absent" "$TEAM_TESTING" 'library exposes:.*`require_absent`'
TEAM_SCRATCH=$(section .buildit/guidelines/team-practices.md '## .scratch/')
in_text "team-practices: tracking sections list Branch and Worktree path" "$TEAM_SCRATCH" 'Status · Branch · Worktree path'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
