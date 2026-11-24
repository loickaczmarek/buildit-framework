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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
