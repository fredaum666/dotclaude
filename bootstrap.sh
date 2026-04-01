#!/bin/bash
# Initializes a new project from dotclaude, or adds .claude/ config to an existing project.
# Two modes:
#   Clone mode — run from a non-git or empty directory: creates a new project folder
#   Init mode  — run from inside an existing git repo: adds .claude/ config to it
# Usage: bash bootstrap.sh
#        curl -fsSL https://raw.githubusercontent.com/fredaum666/dotclaude/main/bootstrap.sh | bash

set -euo pipefail

DOTCLAUDE_REPO="https://github.com/fredaum666/dotclaude.git"
UPSTREAM_REMOTE="upstream"

# ── Helpers ───────────────────────────────────────────────────────────────────

info()    { echo "  $*"; }
success() { echo "✓ $*"; }
warn()    { echo "⚠ $*" >&2; }
abort()   { echo "Error: $*" >&2; exit 1; }

ask() {
  local __var="$1" __prompt="$2"
  read -r -p "$__prompt " __val
  printf -v "$__var" '%s' "$__val"
}

confirm() {
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ── Preflight ─────────────────────────────────────────────────────────────────

command -v git >/dev/null 2>&1 || abort "git is not installed."
command -v jq  >/dev/null 2>&1 || warn "jq is not installed — hooks will fail. Install it: brew install jq (macOS) or apt install jq (Linux)"

# ── Detect mode ───────────────────────────────────────────────────────────────

if git rev-parse --git-dir >/dev/null 2>&1; then
  MODE="init"
else
  MODE="clone"
fi

echo ""
echo "dotclaude bootstrap"
echo "───────────────────"

# ── Clone mode ────────────────────────────────────────────────────────────────

if [ "$MODE" = "clone" ]; then
  info "No git repo detected — running in clone mode."
  echo ""

  ask PROJECT_NAME "Project name:"
  [ -z "$PROJECT_NAME" ] && abort "Project name cannot be empty."

  if [ -e "$PROJECT_NAME" ]; then
    abort "'$PROJECT_NAME' already exists in the current directory."
  fi

  echo ""
  info "Cloning dotclaude into '$PROJECT_NAME'..."
  git clone --quiet "$DOTCLAUDE_REPO" "$PROJECT_NAME"
  cd "$PROJECT_NAME"

  # Keep dotclaude as upstream, clear origin (user sets their own)
  git remote rename origin "$UPSTREAM_REMOTE"

  success "Cloned and set upstream → dotclaude"

# ── Init mode ─────────────────────────────────────────────────────────────────

else
  info "Git repo detected — running in init mode."
  echo ""

  PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")

  confirm "Add .claude/ config to '$PROJECT_NAME'?" || { echo "Aborted."; exit 0; }

  # Check upstream doesn't already exist
  if git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
    warn "Remote '$UPSTREAM_REMOTE' already exists ($(git remote get-url "$UPSTREAM_REMOTE")). Skipping upstream setup."
    SKIP_UPSTREAM=1
  else
    SKIP_UPSTREAM=0
  fi

  # Pull dotclaude into a temp dir and copy .claude/ across
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  echo ""
  info "Fetching dotclaude config..."
  git clone --quiet --depth 1 "$DOTCLAUDE_REPO" "$TMP_DIR/dotclaude"

  mkdir -p .claude

  # Copy each subdirectory — skip if already present, warn user
  for dir in rules skills agents hooks; do
    if [ -d ".claude/$dir" ]; then
      warn ".claude/$dir already exists — skipping (merge manually if needed)"
    else
      cp -r "$TMP_DIR/dotclaude/$dir" ".claude/$dir"
      info "Copied .claude/$dir"
    fi
  done

  # Copy settings.json
  if [ -f ".claude/settings.json" ]; then
    warn ".claude/settings.json already exists — skipping"
  else
    cp "$TMP_DIR/dotclaude/settings.json" ".claude/settings.json"
    info "Copied .claude/settings.json"
  fi

  # Copy CLAUDE.md to project root
  if [ -f "CLAUDE.md" ]; then
    warn "CLAUDE.md already exists at project root — skipping"
  else
    cp "$TMP_DIR/dotclaude/CLAUDE.md" "./CLAUDE.md"
    info "Copied CLAUDE.md"
  fi

  # Copy bootstrap.sh and update.sh
  if [ -f "bootstrap.sh" ]; then
    warn "bootstrap.sh already exists — skipping (run 'bash update.sh' to update it)"
  else
    cp "$TMP_DIR/dotclaude/bootstrap.sh" "./bootstrap.sh"
    info "Copied bootstrap.sh"
  fi

  if [ -f "update.sh" ]; then
    warn "update.sh already exists — skipping"
  else
    cp "$TMP_DIR/dotclaude/update.sh" "./update.sh"
    info "Copied update.sh"
  fi

  # Copy CLAUDE.local.md.example
  [ ! -f "CLAUDE.local.md.example" ] && cp "$TMP_DIR/dotclaude/CLAUDE.local.md.example" "./CLAUDE.local.md.example"

  find .claude/hooks -maxdepth 1 -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
  chmod +x bootstrap.sh update.sh 2>/dev/null || true

  # Add CLAUDE.local.md to .gitignore
  if [ -f ".gitignore" ]; then
    if ! grep -q "CLAUDE.local.md" .gitignore; then
      echo "CLAUDE.local.md" >> .gitignore
      info "Added CLAUDE.local.md to .gitignore"
    fi
  else
    echo "CLAUDE.local.md" > .gitignore
    info "Created .gitignore with CLAUDE.local.md"
  fi

  # Set upstream remote
  if [ "${SKIP_UPSTREAM:-0}" -eq 0 ]; then
    git remote add "$UPSTREAM_REMOTE" "$DOTCLAUDE_REPO"
    success "Set upstream → dotclaude"
  fi
fi

# ── Commit first ─────────────────────────────────────────────────────────────

if [ "$MODE" = "clone" ]; then
  # Remove inner README files that waste tokens at runtime
  find .claude -name "README.md" -delete 2>/dev/null || true

  for _f in .claude/ CLAUDE.md CLAUDE.local.md.example settings.json bootstrap.sh update.sh .gitignore; do
    [ -e "$_f" ] && git add "$_f"
  done
  git commit --quiet -m "chore: initialize project from dotclaude"

elif [ "$MODE" = "init" ]; then
  git add .claude/ CLAUDE.md bootstrap.sh update.sh .gitignore 2>/dev/null || true
  [ -f "CLAUDE.local.md.example" ] && git add CLAUDE.local.md.example 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    git commit --quiet -m "chore: add dotclaude config"
  else
    info "Nothing new to commit — config files already present."
  fi
fi

# ── GitHub remote setup (both modes) ─────────────────────────────────────────

echo ""
echo "GitHub remote setup:"
echo "  1) I have an existing GitHub repo"
echo "  2) Create a new GitHub repo for me"
echo "  3) Skip for now"
echo ""
ask GH_CHOICE "Choose [1/2/3]:"

GH_PUSHED=0

case "$GH_CHOICE" in
  1)
    ask REMOTE_URL "GitHub repo URL (e.g. https://github.com/you/project.git):"
    [ -z "$REMOTE_URL" ] && abort "URL cannot be empty."
    git remote add origin "$REMOTE_URL" 2>/dev/null || git remote set-url origin "$REMOTE_URL"
    success "Set origin → $REMOTE_URL"
    ;;
  2)
    if ! command -v gh >/dev/null 2>&1; then
      warn "gh CLI not installed — skipping GitHub repo creation."
      warn "Install it: https://cli.github.com, then run: gh repo create"
    else
      echo ""
      ask REPO_NAME "Repo name (default: $PROJECT_NAME):"
      [ -z "$REPO_NAME" ] && REPO_NAME="$PROJECT_NAME"

      echo "  1) Public"
      echo "  2) Private"
      ask VISIBILITY_CHOICE "Visibility [1/2]:"
      case "$VISIBILITY_CHOICE" in
        1) VISIBILITY="--public" ;;
        *) VISIBILITY="--private" ;;
      esac

      gh repo create "$REPO_NAME" $VISIBILITY --source=. --remote=origin --push
      success "Created GitHub repo and pushed"
      GH_PUSHED=1
    fi
    ;;
  *)
    info "Skipping GitHub setup. Add a remote later with: git remote add origin <url>"
    ;;
esac

# ── Push if not already pushed ────────────────────────────────────────────────

if git remote get-url origin >/dev/null 2>&1 && [ "$GH_PUSHED" -eq 0 ]; then
  if git push -u origin main --quiet 2>/dev/null || git push -u origin HEAD --quiet 2>/dev/null; then
    success "Pushed to origin"
  else
    warn "Push failed — check your remote URL and credentials, then push manually."
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

# ── Plugins ───────────────────────────────────────────────────────────────────

if command -v claude >/dev/null 2>&1; then
  PLUGIN_LIST=$(claude plugin list 2>/dev/null || true)
  MCP_LIST=$(claude mcp list 2>/dev/null || true)

  # Superpowers — structured workflows (brainstorming, TDD, debugging, planning)
  if ! echo "$MCP_LIST" | grep -q "superpowers"; then
    echo ""
    info "Installing superpowers plugin..."
    if claude mcp add superpowers --yes -- npx -y claude-superpowers@latest 2>/dev/null; then
      success "Superpowers plugin installed"
    else
      warn "Superpowers install failed — run manually: claude mcp add superpowers -- npx -y claude-superpowers@latest"
    fi
  else
    info "Superpowers already installed — skipping"
  fi

  # Frontend-design — production-grade UI generation
  if ! echo "$PLUGIN_LIST" | grep -q "frontend-design"; then
    echo ""
    info "Installing frontend-design plugin..."
    if claude plugin install frontend-design --yes 2>/dev/null; then
      success "Frontend-design plugin installed"
    else
      warn "Frontend-design install failed — run manually: claude plugin install frontend-design"
    fi
  else
    info "Frontend-design already installed — skipping"
  fi

  # Playwright — browser automation and E2E testing
  if ! echo "$PLUGIN_LIST" | grep -q "playwright"; then
    echo ""
    info "Installing Playwright plugin..."
    if claude plugin install playwright --yes 2>/dev/null; then
      success "Playwright plugin installed"
    else
      warn "Playwright install failed — run manually: claude plugin install playwright"
    fi
  else
    info "Playwright already installed — skipping"
  fi

  # Feature-dev — guided feature development workflows
  if ! echo "$PLUGIN_LIST" | grep -q "feature-dev"; then
    echo ""
    info "Installing feature-dev plugin..."
    if claude plugin install feature-dev --yes 2>/dev/null; then
      success "Feature-dev plugin installed"
    else
      warn "Feature-dev install failed — run manually: claude plugin install feature-dev"
    fi
  else
    info "Feature-dev already installed — skipping"
  fi
fi

echo ""
echo "────────────────────────────────────────────"
success "Bootstrap complete!"
echo ""
if [ "$MODE" = "clone" ]; then
  echo "  Next steps:"
  echo "  1. cd '$PROJECT_NAME'"
  echo "  2. Add your first code"
  echo "  3. Open Claude Code and run: /setupdotclaude"
else
  echo "  Next steps:"
  echo "  1. Add your first code (or continue where you left off)"
  echo "  2. Open Claude Code and run: /setupdotclaude"
fi
echo ""
echo "  To pull future dotclaude config updates: bash update.sh"
echo ""
