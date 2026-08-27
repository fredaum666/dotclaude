# Project Instructions

> REPLACE: Customize this file for your project. Delete sections that don't apply — every line costs tokens. Code style lives in .claude/rules/code-quality.md — don't duplicate here. Run `/setupdotclaude` to auto-customize, or edit manually and delete all `> REPLACE:` blocks when done. Keep the **Maintaining This File** section.

## Commands

```bash
# Build
npm run build            # or: cargo build, go build ./..., make build

# Test
npm test                 # run full suite
npm test -- path/to/file # run single test file

# Lint & Format
npm run lint             # check style
npm run lint:fix         # auto-fix style
npm run typecheck        # type checking

# Dev
npm run dev              # start dev server
```

## Architecture

> REPLACE: Describe non-obvious architectural decisions. Don't list files — Claude can explore.

- `src/` — application source
- `src/api/` — REST endpoints (versioned: `/v1/`)
- `src/services/` — business logic (no direct DB access from controllers)
- `src/models/` — data models and types

## Key Decisions

> REPLACE: Record WHY non-obvious choices were made. This is the most valuable section. Examples: "Auth tokens in httpOnly cookies because XSS risk", "Billing is a separate module for audit independence".

## Domain Knowledge

> REPLACE: Terms, abbreviations, or concepts that aren't obvious from the code. Example: "SKU" = Stock Keeping Unit, the unique product identifier from our warehouse system.

## Workflow

- Run typecheck after making a series of code changes
- Prefer fixing the root cause over adding workarounds
- When unsure about approach, use plan mode (`Shift+Tab`) before coding
- Pick the matching skill/agent from `.claude/rules/skills.md` **before** starting work — don't wait to be asked
- If a plugin or skill referenced there is missing, install it: `bash bootstrap.sh --install-only`

## Don'ts

- Don't modify generated files (`*.gen.ts`, `*.generated.*`)

## Maintaining This File

This `CLAUDE.md` was seeded from the dotclaude bootstrap and is now **this project's** instructions file. The agent working in this repo owns it:

- On first run, execute `/setupdotclaude` to replace the template sections above with the real stack, then remove every `> REPLACE:` block. Keep this section.
- Keep it current as the project evolves: record new **Key Decisions** (the *why*), **Domain Knowledge**, changed commands, and any project-specific skills/agents added to `.claude/`. Prune entries that stop being true.
- Add project-specific guidance the moment it would have saved a mistake — conventions, gotchas, things the user corrected. Anything worth telling a new teammate on day one belongs here.
- Which skills/agents to use, and when, lives in `.claude/rules/skills.md` (auto-loaded every session, managed by dotclaude). Don't duplicate it here.
- `bash update.sh` pulls dotclaude updates — new rules, skills, agents, and `bootstrap.sh` — adding new files and only overwriting dotclaude-managed ones (`rules/skills.md`, `skills/setupdotclaude/`). It never touches this file or files you customized.
