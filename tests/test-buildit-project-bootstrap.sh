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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
