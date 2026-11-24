#!/usr/bin/env bash
# Structural tests for the buildit-worktree skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-worktree/SKILL.md"
SKILL_START="skills/buildit-feature-start/SKILL.md"
SKILL_RUN="skills/buildit-feature-run/SKILL.md"
SKILL_BOOTSTRAP="skills/buildit-project-bootstrap/SKILL.md"
README="README.md"

# AT-1: buildit-worktree SKILL.md mentions .worktrees/ and feature/YYYY-MM-DD
require_text "AT-1a: skill mentions .worktrees/" "$SKILL" '.worktrees/'
require_regex "AT-1b: skill mentions feature/YYYY-MM-DD branch convention" "$SKILL" 'feature/YYYY-MM-DD'

# AT-2: buildit-worktree SKILL.md mentions absolute path output
require_regex "AT-2: skill mentions absolute path (realpath or pwd)" "$SKILL" '(realpath|absolute path|WORKTREE_PATH)'

# AT-3: buildit-worktree SKILL.md mentions git -C
require_text "AT-3: skill instructs to use git -C" "$SKILL" 'git -C'

# AT-4: buildit-feature-start does NOT reference using-git-worktrees, DOES reference buildit-worktree
require_absent "AT-4a: buildit-feature-start does not reference using-git-worktrees" "$SKILL_START" 'using-git-worktrees'
require_text "AT-4b: buildit-feature-start references buildit-worktree" "$SKILL_START" 'buildit-worktree'

# AT-5: buildit-feature-start tracking file template has ## Worktree path field
require_text "AT-5: buildit-feature-start template has ## Worktree path field" "$SKILL_START" '## Worktree path'

# AT-6: buildit-feature-run mentions git -C in worktree context
require_text "AT-6: buildit-feature-run mentions git -C" "$SKILL_RUN" 'git -C'

# AT-7: buildit-feature-run mentions Bash(cd */.worktrees/*
require_text "AT-7: buildit-feature-run mentions Bash(cd */.worktrees/* permission" "$SKILL_RUN" 'Bash(cd */.worktrees/*'

# AT-8: buildit-project-bootstrap mentions Bash(cd */.worktrees/*)
require_text "AT-8: buildit-project-bootstrap mentions Bash(cd */.worktrees/*)" "$SKILL_BOOTSTRAP" 'Bash(cd */.worktrees/*)'

# AT-9: README mentions buildit-worktree as internal skill
require_text "AT-9: README mentions buildit-worktree" "$README" 'buildit-worktree'

# AT-BR-1: buildit-worktree returns a machine-readable Branch: line
require_text "AT-BR-1: buildit-worktree outputs a Branch: <BRANCH> line" "skills/buildit-worktree/SKILL.md" 'Branch: <BRANCH>'
require_text "AT-BR-1: caller records the branch in ## Branch" "skills/buildit-worktree/SKILL.md" '`## Branch`'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
