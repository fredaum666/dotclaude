#!/bin/bash
# Pulls the latest .claude/ config, bootstrap.sh, and update.sh from the dotclaude upstream.
# Run from inside any project bootstrapped from dotclaude.
# Usage: bash update.sh

# Re-exec from a temp copy so the script can safely overwrite itself
if [ -z "${_UPDATE_SH_REEXEC:-}" ]; then
  _TMP=$(mktemp /tmp/update.sh.XXXXXX)
  cp "$0" "$_TMP"
  chmod +x "$_TMP"
  _UPDATE_SH_REEXEC=1 exec bash "$_TMP" "$@"
fi

set -euo pipefail

UPSTREAM_REMOTE="upstream"
UPSTREAM_BRANCH="main"
MERGE_PATHS=(".claude/" "bootstrap.sh" "update.sh")

# ── Preflight ────────────────────────────────────────────────────────────────

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is not installed." >&2
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not inside a git repository. Run this from your project root." >&2
  exit 1
fi

if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  echo "Error: no '$UPSTREAM_REMOTE' remote found." >&2
  echo "Set it with:" >&2
  echo "  git remote add upstream https://github.com/fredaum666/dotclaude.git" >&2
  exit 1
fi

# ── Fetch ────────────────────────────────────────────────────────────────────

echo "Fetching from $UPSTREAM_REMOTE..."
git fetch "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH"

# Check if there's anything to update
if ! UPSTREAM_SHA=$(git rev-parse "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" 2>/dev/null); then
  echo "Error: could not resolve $UPSTREAM_REMOTE/$UPSTREAM_BRANCH after fetch." >&2
  exit 1
fi
MERGE_BASE=$(git merge-base HEAD "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" 2>/dev/null || echo "")

CHANGED=0
for path in "${MERGE_PATHS[@]}"; do
  if [ -n "$MERGE_BASE" ]; then
    if ! git diff --quiet "$MERGE_BASE" "$UPSTREAM_SHA" -- "$path" 2>/dev/null; then
      CHANGED=1
      break
    fi
  else
    CHANGED=1
    break
  fi
done

if [ "$CHANGED" -eq 0 ]; then
  echo "Already up to date. No changes in .claude/, bootstrap.sh, or update.sh."
  exit 0
fi

# ── Show what will change ─────────────────────────────────────────────────────

echo ""
echo "Changes coming from upstream:"
for path in "${MERGE_PATHS[@]}"; do
  if [ -n "$MERGE_BASE" ]; then
    FILES=$(git diff --name-only "$MERGE_BASE" "$UPSTREAM_SHA" -- "$path" 2>/dev/null)
  else
    # No common ancestor — show files that differ from current working tree
    FILES=$(git diff --name-only HEAD "$UPSTREAM_SHA" -- "$path" 2>/dev/null)
  fi
  if [ -n "$FILES" ]; then
    echo "$FILES" | sed 's/^/  /'
  fi
done

echo ""
read -r -p "Apply these changes? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# ── Apply upstream changes ────────────────────────────────────────────────────

# Warn if tracked files under the update paths have local modifications
DIRTY=$(git status --porcelain -- ".claude/" "bootstrap.sh" "update.sh" 2>/dev/null | grep -v '^??')
if [ -n "$DIRTY" ]; then
  echo "Warning: the following files have local modifications and will be overwritten:" >&2
  echo "$DIRTY" | sed 's/^/  /' >&2
  read -r -p "Continue and overwrite? [y/N] " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo ""
echo "Applying changes..."
for path in "${MERGE_PATHS[@]}"; do
  git checkout "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" -- "$path" || true
done

# Make hooks executable
find .claude/hooks -maxdepth 1 -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

echo ""
echo "Done. Review the changes with 'git diff --cached', then commit:"
echo "  git commit -m 'chore: update .claude config from dotclaude upstream'"
