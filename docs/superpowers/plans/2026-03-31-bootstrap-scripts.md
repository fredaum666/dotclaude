# Bootstrap & Update Scripts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `bootstrap.sh` and `update.sh` at the repo root, and update `README.md` with a one-liner quick start, so any developer can create or initialize a project from dotclaude with a single `curl | bash` command.

**Architecture:** Two standalone bash scripts at the repo root. `bootstrap.sh` detects whether it's running inside an existing git repo (init mode) or a fresh/non-git directory (clone mode), handles GitHub remote setup via `gh`, and commits `.claude/` config as the first commit. `update.sh` pulls only `.claude/`, `bootstrap.sh`, and `update.sh` from the `upstream` remote. README gets a Quick Start section at the top with the one-liner.

**Tech Stack:** bash, git, gh CLI, jq

---

## Files

| File | Action | Purpose |
|------|--------|---------|
| `bootstrap.sh` | Create | Project initializer — clone mode + init mode + GitHub flow |
| `update.sh` | Create | Config updater — fetch + merge from upstream |
| `README.md` | Modify | Add Quick Start one-liner section at the top |

---

### Task 1: Create `update.sh`

**Files:**
- Create: `update.sh`

- [ ] **Step 1: Write `update.sh`**

```bash
#!/bin/bash
# Pulls the latest .claude/ config, bootstrap.sh, and update.sh from the dotclaude upstream.
# Run from inside any project bootstrapped from dotclaude.
# Usage: bash update.sh

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
  echo "  git remote add upstream https://github.com/poshan0126/dotclaude.git" >&2
  exit 1
fi

# ── Fetch ────────────────────────────────────────────────────────────────────

echo "Fetching from $UPSTREAM_REMOTE..."
git fetch "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH"

# Check if there's anything to update
UPSTREAM_SHA=$(git rev-parse "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")
MERGE_BASE=$(git merge-base HEAD "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" 2>/dev/null || echo "")

CHANGED=0
for path in "${MERGE_PATHS[@]}"; do
  if [ -n "$MERGE_BASE" ]; then
    COUNT=$(git diff --name-only "$MERGE_BASE" "$UPSTREAM_SHA" -- "$path" 2>/dev/null | wc -l | tr -d ' ')
  else
    COUNT=1
  fi
  if [ "$COUNT" -gt 0 ]; then
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
    FILES=$(git ls-tree -r --name-only "$UPSTREAM_SHA" -- "$path" 2>/dev/null)
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

# ── Merge ────────────────────────────────────────────────────────────────────

echo ""
echo "Merging..."
git merge "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" --no-commit --no-ff -- "${MERGE_PATHS[@]}" 2>/dev/null || true

# Make hooks executable
if [ -d ".claude/hooks" ]; then
  chmod +x .claude/hooks/*.sh 2>/dev/null || true
fi

echo ""
echo "Done. Review the changes with 'git diff --cached', then commit:"
echo "  git commit -m 'chore: update .claude config from dotclaude upstream'"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x update.sh
```

- [ ] **Step 3: Verify it shows a sensible error outside a git repo**

```bash
cd /tmp && bash /Users/fredmagalhaes/App/dotclaude/update.sh
```

Expected output:
```
Error: not inside a git repository. Run this from your project root.
```

- [ ] **Step 4: Commit**

```bash
cd /Users/fredmagalhaes/App/dotclaude
git add update.sh
git commit -m "feat: add update.sh to pull config updates from upstream"
```

---

### Task 2: Create `bootstrap.sh`

**Files:**
- Create: `bootstrap.sh`

- [ ] **Step 1: Write `bootstrap.sh`**

```bash
#!/bin/bash
# Initializes a new project from dotclaude, or adds .claude/ config to an existing project.
# Two modes:
#   Clone mode — run from a non-git or empty directory: creates a new project folder
#   Init mode  — run from inside an existing git repo: adds .claude/ config to it
# Usage: bash bootstrap.sh
#        curl -fsSL https://raw.githubusercontent.com/poshan0126/dotclaude/main/bootstrap.sh | bash

set -euo pipefail

DOTCLAUDE_REPO="https://github.com/poshan0126/dotclaude.git"
UPSTREAM_REMOTE="upstream"

# ── Helpers ───────────────────────────────────────────────────────────────────

info()    { echo "  $*"; }
success() { echo "✓ $*"; }
warn()    { echo "⚠ $*" >&2; }
abort()   { echo "Error: $*" >&2; exit 1; }

ask() {
  # ask <varname> <prompt>
  local __var="$1" __prompt="$2"
  read -r -p "$__prompt " __val
  printf -v "$__var" '%s' "$__val"
}

confirm() {
  # confirm <prompt> — returns 0 for yes, 1 for no
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

  # Rename upstream to keep dotclaude as upstream, clear origin
  git remote rename origin "$UPSTREAM_REMOTE"
  git remote remove origin 2>/dev/null || true

  success "Cloned and set upstream → dotclaude"

# ── Init mode ─────────────────────────────────────────────────────────────────

else
  info "Git repo detected — running in init mode."
  echo ""

  PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")

  confirm "Add .claude/ config to '$PROJECT_NAME'?" || { echo "Aborted."; exit 0; }

  # Check upstream doesn't already exist
  if git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
    warn "Remote '$UPSTREAM_REMOTE' already exists ($(git remote get-url $UPSTREAM_REMOTE)). Skipping upstream setup."
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
  cp "$TMP_DIR/dotclaude/bootstrap.sh" "./bootstrap.sh"
  cp "$TMP_DIR/dotclaude/update.sh" "./update.sh"
  info "Copied bootstrap.sh and update.sh"

  # Copy CLAUDE.local.md.example
  [ ! -f "CLAUDE.local.md.example" ] && cp "$TMP_DIR/dotclaude/CLAUDE.local.md.example" "./CLAUDE.local.md.example"

  chmod +x .claude/hooks/*.sh bootstrap.sh update.sh

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
  if [ "$SKIP_UPSTREAM" -eq 0 ]; then
    git remote add "$UPSTREAM_REMOTE" "$DOTCLAUDE_REPO"
    success "Set upstream → dotclaude"
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
        2) VISIBILITY="--private" ;;
        *) VISIBILITY="--private" ;;
      esac

      gh repo create "$REPO_NAME" $VISIBILITY --source=. --remote=origin --push
      success "Created GitHub repo and pushed"
      GH_PUSHED=1
    fi
    ;;
  3)
    info "Skipping GitHub setup. Add a remote later with: git remote add origin <url>"
    ;;
  *)
    info "Skipping GitHub setup."
    ;;
esac

# ── Initial commit (clone mode only — init mode stages and commits) ───────────

if [ "$MODE" = "clone" ]; then
  # Remove inner README files that waste tokens at runtime
  find .claude -name "README.md" -delete 2>/dev/null || true

  git add .claude/ CLAUDE.md CLAUDE.local.md.example settings.json bootstrap.sh update.sh .gitignore 2>/dev/null || git add -A
  git commit --quiet -m "chore: initialize project from dotclaude"

  # Push if we have an origin and haven't pushed yet
  if git remote get-url origin >/dev/null 2>&1 && [ "${GH_PUSHED:-0}" -eq 0 ]; then
    git push -u origin main --quiet
    success "Pushed to origin"
  fi
elif [ "$MODE" = "init" ]; then
  # Stage the new .claude/ files
  git add .claude/ CLAUDE.md bootstrap.sh update.sh .gitignore 2>/dev/null || true
  [ -f "CLAUDE.local.md.example" ] && git add CLAUDE.local.md.example 2>/dev/null || true
  git commit --quiet -m "chore: add dotclaude config"

  if git remote get-url origin >/dev/null 2>&1 && [ "${GH_PUSHED:-0}" -eq 0 ]; then
    git push -u origin main --quiet 2>/dev/null || git push -u origin HEAD --quiet 2>/dev/null || true
    success "Pushed to origin"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────────"
success "Bootstrap complete!"
echo ""
if [ "$MODE" = "clone" ]; then
  echo "  Next steps:"
  echo "  1. cd $PROJECT_NAME"
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
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x bootstrap.sh
```

- [ ] **Step 3: Smoke test — verify it aborts cleanly when run inside a non-empty non-git dir**

Run in a temp dir that already has files:
```bash
cd /tmp && mkdir bs_test && echo "hello" > /tmp/bs_test/file.txt && cd bs_test
bash /Users/fredmagalhaes/App/dotclaude/bootstrap.sh
# Type a project name that matches "bs_test" when prompted
```

Expected: error "'bs_test' already exists in the current directory." OR proceeds to init mode (since /tmp/bs_test is not a git repo, it will be clone mode, and bs_test dir already exists — should abort).

Actually since we're *inside* bs_test and it's not a git repo, it will run in clone mode and ask for a project name. If you type "bs_test" → it sees the dir exists and aborts. Type anything else → it tries to clone. That's correct behavior.

```bash
cd /tmp && rm -rf bs_test
```

- [ ] **Step 4: Commit**

```bash
cd /Users/fredmagalhaes/App/dotclaude
git add bootstrap.sh
git commit -m "feat: add bootstrap.sh for new and existing project setup"
```

---

### Task 3: Update README.md with Quick Start one-liner

**Files:**
- Modify: `README.md` (top of file, before "Why This Exists")

- [ ] **Step 1: Add Quick Start section at the very top of README.md**

Insert after the `# dotclaude` heading and the one-liner description, before `## Why This Exists`:

```markdown
## Quick Start

**New project:**
```bash
curl -fsSL https://raw.githubusercontent.com/poshan0126/dotclaude/main/bootstrap.sh | bash
```

**Existing project:**
```bash
cd your-existing-project
curl -fsSL https://raw.githubusercontent.com/poshan0126/dotclaude/main/bootstrap.sh | bash
```

That's it. Bootstrap detects the context, sets everything up, and tells you what to do next.

> **Prerequisite:** `git`, `jq`, and optionally `gh` (GitHub CLI). See [Getting Started](#getting-started) for install commands.
```

- [ ] **Step 2: Verify README renders correctly**

```bash
head -40 README.md
```

Expected: `# dotclaude` → short description → `## Quick Start` section with two code blocks.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add Quick Start one-liner to README"
```

---

### Task 4: Final wiring — make bootstrap.sh and update.sh included in the dotclaude repo properly

**Files:**
- Modify: `.gitignore` (verify bootstrap.sh and update.sh are not ignored)

- [ ] **Step 1: Verify .gitignore doesn't exclude the scripts**

```bash
cat .gitignore
```

Expected: `.gitignore` should contain `CLAUDE.local.md` and `settings.local.json` but NOT `bootstrap.sh` or `update.sh`.

- [ ] **Step 2: Verify both scripts are tracked**

```bash
git ls-files bootstrap.sh update.sh
```

Expected:
```
bootstrap.sh
update.sh
```

- [ ] **Step 3: Final check — list all committed files at root**

```bash
git ls-files | grep -v "^\.claude\|^docs\|^agents\|^hooks\|^rules\|^skills"
```

Expected output includes: `CLAUDE.md`, `CLAUDE.local.md.example`, `README.md`, `CONTRIBUTING.md`, `bootstrap.sh`, `update.sh`, `settings.json`, `settings.local.json.example`, `.gitignore`

- [ ] **Step 4: Push everything**

```bash
git push origin main
```
