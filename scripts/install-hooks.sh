#!/usr/bin/env bash
# Configures git to use the repo's tracked hooks in scripts/hooks/.
# Idempotent: safe to run multiple times.

REPO_ROOT="$(git rev-parse --show-toplevel)"

git -C "$REPO_ROOT" config core.hooksPath scripts/hooks

echo "Done. Git hooks path set to scripts/hooks/."
echo "The pre-push hook will now run tests/run-all.sh before every push."
