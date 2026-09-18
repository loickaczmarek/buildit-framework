#!/usr/bin/env bash
# Cross-skill structural invariants.
# Verifies every skill satisfies the 7 structural invariants.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILLS=(
  buildit-feature-discover
  buildit-feature-start
  buildit-feature-build
  buildit-feature-validate
  buildit-feature-ship
  buildit-project-bootstrap
  buildit-feature-run
  buildit-worktree
)

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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
