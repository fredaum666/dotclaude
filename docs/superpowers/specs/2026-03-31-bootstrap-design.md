# Bootstrap & Update Scripts Design

**Date:** 2026-03-31

## Goal

Ship two scripts — `bootstrap.sh` and `update.sh` — that make `dotclaude` the base for every new project, with a clear path to propagate config improvements back to existing projects.

---

## Architecture

Two scripts at the repo root. Both get cloned into every project alongside `.claude/`, so the workflow is self-contained.

### `bootstrap.sh`

Detects which of two modes to run:

**Clone mode** — run from an empty or non-git directory:
1. Prompt for project name
2. Clone `dotclaude` into `<project-name>/`
3. `cd` into it, set `upstream` to the dotclaude remote URL
4. GitHub flow (see below)
5. Commit `.claude/` config as the initial commit on `main`
6. Print reminder

**Init mode** — run from inside an existing git repo that has no `upstream` remote:
1. Confirm with user before proceeding
2. Copy `.claude/` config files into the repo (skip if already present, warn)
3. Set `upstream` to the dotclaude remote URL
4. GitHub flow (see below)
5. Stage and commit `.claude/` config
6. Print reminder

**GitHub flow** (shared, both modes):
- Ask: "Do you have a GitHub repo, or should I create one?" [existing/create/skip]
- If `create`: run `gh repo create` — prompt for name and visibility (public/private)
- If `existing`: prompt for the remote URL
- If `skip`: leave `origin` unset, print a note
- In all non-skip cases: set `origin`, push `main`

**End state** (both modes):
- `upstream` → dotclaude repo (for future config pulls)
- `origin` → new project repo (or unset if skipped)
- `.claude/` config committed on `main`
- Printed reminder: "Add your first code, then run `/setupdotclaude` in Claude Code to tailor the config to your stack."

**Error handling:**
- `gh` not installed → skip GitHub creation, print: "Install gh CLI to enable GitHub repo creation: https://cli.github.com"
- Already has `upstream` remote (init mode) → warn and skip, don't overwrite
- Non-empty non-git directory (clone mode) → abort: "Directory is not empty and not a git repo. Create an empty directory or run bootstrap inside an existing git repo."
- Git not installed → abort immediately with install hint

---

### `update.sh`

Pulls the latest `.claude/` config, `bootstrap.sh`, and `update.sh` from the base repo into the current project.

```
git fetch upstream
git merge upstream/main -- .claude/ bootstrap.sh update.sh
```

Behavior:
- Verifies `upstream` remote exists; if not, prints setup instructions and exits 1
- Prints a summary of changed files after merge
- Exits cleanly (exit 0) if nothing to update
- Does NOT auto-commit — lets the developer review the diff first

---

## Files

| File | Purpose |
|------|---------|
| `bootstrap.sh` | Create or initialize a new project from dotclaude |
| `update.sh` | Pull base config updates into an existing project |

Both files live at the repo root and are committed into every project created from this base.

---

## Out of Scope

- Auto-running `/setupdotclaude` — that's a manual step after first code is written
- Handling monorepos with multiple `.claude/` configs
- Windows support (bash scripts only)
