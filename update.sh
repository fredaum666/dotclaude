#!/bin/bash
# Pulls the latest dotclaude config into a project bootstrapped from dotclaude.
# Run from inside the project root. Usage: bash update.sh
#
# What it does:
#   - bootstrap.sh, update.sh                 → always updated
#   - rules/ skills/ agents/ hooks/ settings.json
#                                             → new files added; files you changed are
#                                                left alone (listed for manual merge);
#                                                dotclaude-managed files are overwritten
#   - CLAUDE.md                                → never touched
#   - then offers to install new plugins/skills (bash bootstrap.sh --install-only)

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
CONFIG_DIRS=(rules skills agents hooks)          # live under .claude/ (init mode) or ./ (clone mode)
ROOT_FILES=(bootstrap.sh update.sh)
CONFIG_FILES=(settings.json)                     # same location rule as CONFIG_DIRS
# Files dotclaude owns outright — overwritten even if they differ locally
MANAGED=("rules/skills.md" "skills/setupdotclaude/SKILL.md")

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

# Where config lives in this project: .claude/ (init mode) or repo root (clone mode)
if [ -d ".claude" ]; then
  CONFIG_ROOT=".claude"
elif [ -d "rules" ] || [ -d "skills" ]; then
  CONFIG_ROOT="."
else
  CONFIG_ROOT=".claude"
fi

# ── Fetch ────────────────────────────────────────────────────────────────────

echo "Fetching from $UPSTREAM_REMOTE..."
git fetch "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH"

if ! UPSTREAM_SHA=$(git rev-parse "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" 2>/dev/null); then
  echo "Error: could not resolve $UPSTREAM_REMOTE/$UPSTREAM_BRANCH after fetch." >&2
  exit 1
fi

# Export upstream config into a temp dir so we can compare file by file
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
git archive "$UPSTREAM_SHA" "${CONFIG_DIRS[@]}" "${CONFIG_FILES[@]}" "${ROOT_FILES[@]}" 2>/dev/null | tar -x -C "$TMP_DIR"

# ── Plan ─────────────────────────────────────────────────────────────────────

ADD=(); UPDATE=(); SKIP=(); ROOT_CHANGED=()

is_managed() {
  local f; for f in "${MANAGED[@]}"; do [ "$1" = "$f" ] && return 0; done; return 1
}

for f in "${ROOT_FILES[@]}"; do
  [ -f "$TMP_DIR/$f" ] || continue
  if [ ! -f "$f" ] || ! cmp -s "$TMP_DIR/$f" "$f"; then ROOT_CHANGED+=("$f"); fi
done

while IFS= read -r src; do
  rel="${src#"$TMP_DIR"/}"
  case "$rel" in */README.md) continue ;; esac   # repo docs, not runtime config
  dest="$CONFIG_ROOT/$rel"
  if [ ! -f "$dest" ]; then
    ADD+=("$rel")
  elif cmp -s "$src" "$dest"; then
    :
  elif is_managed "$rel"; then
    UPDATE+=("$rel")
  else
    SKIP+=("$rel")
  fi
done < <({ find "${CONFIG_DIRS[@]/#/$TMP_DIR/}" -type f 2>/dev/null; for f in "${CONFIG_FILES[@]}"; do [ -f "$TMP_DIR/$f" ] && echo "$TMP_DIR/$f"; done; } | sort)

if [ ${#ROOT_CHANGED[@]} -eq 0 ] && [ ${#ADD[@]} -eq 0 ] && [ ${#UPDATE[@]} -eq 0 ]; then
  echo "Already up to date."
  if [ ${#SKIP[@]} -gt 0 ]; then
    echo "  (${#SKIP[@]} file(s) differ from upstream but are yours to keep — see below)"
    printf '    %s\n' "${SKIP[@]}"
  fi
  exit 0
fi

echo ""
echo "Changes coming from upstream:"
[ ${#ROOT_CHANGED[@]} -gt 0 ] && { echo "  Update:"; printf '    %s\n' "${ROOT_CHANGED[@]}"; }
[ ${#ADD[@]} -gt 0 ]          && { echo "  Add ($CONFIG_ROOT/):"; printf '    %s\n' "${ADD[@]}"; }
[ ${#UPDATE[@]} -gt 0 ]       && { echo "  Overwrite (dotclaude-managed, $CONFIG_ROOT/):"; printf '    %s\n' "${UPDATE[@]}"; }
[ ${#SKIP[@]} -gt 0 ]         && { echo "  Keep yours (differs from upstream — merge manually if wanted):"; printf '    %s\n' "${SKIP[@]}"; }
echo "  CLAUDE.md is never modified."

echo ""
read -r -p "Apply these changes? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# ── Apply ────────────────────────────────────────────────────────────────────

DIRTY=$(git status --porcelain -- "${ROOT_FILES[@]}" "${CONFIG_DIRS[@]/#/$CONFIG_ROOT/}" "${CONFIG_FILES[@]/#/$CONFIG_ROOT/}" 2>/dev/null | grep -v '^??' || true)
if [ -n "$DIRTY" ]; then
  echo "Warning: uncommitted changes in files this update may touch:" >&2
  echo "$DIRTY" | sed 's/^/  /' >&2
  read -r -p "Continue? [y/N] " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo ""
echo "Applying changes..."
for f in ${ROOT_CHANGED[@]+"${ROOT_CHANGED[@]}"}; do
  cp "$TMP_DIR/$f" "$f" && git add "$f"
done
for rel in ${ADD[@]+"${ADD[@]}"} ${UPDATE[@]+"${UPDATE[@]}"}; do
  mkdir -p "$(dirname "$CONFIG_ROOT/$rel")"
  cp "$TMP_DIR/$rel" "$CONFIG_ROOT/$rel" && git add "$CONFIG_ROOT/$rel"
done

find "$CONFIG_ROOT/hooks" -maxdepth 1 -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
chmod +x bootstrap.sh update.sh 2>/dev/null || true

echo ""
echo "Done. Review the changes with 'git diff --cached', then commit:"
echo "  git commit -m 'chore: update .claude config from dotclaude upstream'"
if [ ${#SKIP[@]} -gt 0 ]; then
  echo ""
  echo "Kept your versions of ${#SKIP[@]} file(s). To see what upstream changed in one:"
  echo "  git diff HEAD:$CONFIG_ROOT/${SKIP[0]} $UPSTREAM_REMOTE/$UPSTREAM_BRANCH:${SKIP[0]}"
fi

# ── Install new plugins / community skills ───────────────────────────────────

if [ -f "bootstrap.sh" ]; then
  echo ""
  read -r -p "Install any new plugins and community skills now? [y/N] " INSTALL
  if [[ "$INSTALL" =~ ^[Yy]$ ]]; then
    bash bootstrap.sh --install-only
  else
    echo "Skipped. Run later with: bash bootstrap.sh --install-only"
  fi
fi
