#!/usr/bin/env bash
# Installs git hooks from scripts/hooks/ into .git/hooks/.
# Idempotent: safe to run multiple times.

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="$REPO_ROOT/scripts/hooks"
HOOKS_DST="$REPO_ROOT/.git/hooks"

install_hook() {
  local name="$1"
  local src="$HOOKS_SRC/$name"
  local dst="$HOOKS_DST/$name"

  if [[ -f "$dst" ]] && ! diff -q "$src" "$dst" > /dev/null 2>&1; then
    echo "Notice: overwriting existing $name hook (it differs from the repo version)."
  fi

  cp "$src" "$dst"
  chmod +x "$dst"
  echo "Installed: .git/hooks/$name"
}

install_hook pre-push

echo "Done. Hooks installed from scripts/hooks/."
