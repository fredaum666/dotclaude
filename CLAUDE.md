# Project Instructions

> REPLACE: Customize this file for your project. Delete sections that don't apply — every line costs tokens. Code style lives in .claude/rules/code-quality.md — don't duplicate here. Run `/setupdotclaude` to auto-customize, or edit manually and delete all `> REPLACE:` blocks when done. Keep the **Skills & Agents** and **Maintaining This File** sections — they tell Claude how to work in this repo.

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
- Pick the matching skill/agent from the section below **before** starting work — don't wait to be asked
- If a plugin or skill referenced below is missing, install it: `claude plugin install <name>` for plugins, `bash bootstrap.sh` re-installs community skills

## Skills & Agents — Use Proactively

Skills are invoked with `/name`; agents are delegated to with the Agent tool. **Use them by default whenever the task matches — the user should not have to ask.** Announce which one you're using ("Using /tdd to…"). When several apply, run process skills first (they set the approach), then design/implementation skills, then review.

### Process (superpowers plugin — always first when they apply)

| Situation | Use | Why |
|---|---|---|
| Any new feature, component, or behavior change | `/brainstorming` | Clarifies intent and design before code; prevents building the wrong thing |
| Multi-step task with a spec | `/writing-plans` → `/executing-plans` or `/subagent-driven-development` | Breaks work into verifiable steps |
| Any bug, failing test, or unexpected behavior | `/systematic-debugging` | Root cause before fixes; no guess-and-check |
| Writing any production code | `/test-driven-development` | Failing test first, then minimal code |
| About to say "done" / "fixed" / "passing" | `/verification-before-completion` | Run the checks; evidence before claims |
| Starting isolated feature work | `/using-git-worktrees` | Keeps the main workspace clean |
| Implementation finished | `/finishing-a-development-branch` | Decide merge/PR/cleanup deliberately |

### Project skills (`.claude/skills/`)

| Situation | Use | Why |
|---|---|---|
| Bug from an issue, error, or report | `/debug-fix` | Reproduce → root-cause → fix → regression test, end to end |
| Production is broken now | `/hotfix` | Minimal change on a hotfix branch, critical tests only, ship fast |
| Feature or bugfix that needs tests | `/tdd` | Red-green-refactor loop |
| New or changed code lacks coverage | `/test-writer` | Auto-triggers — writes tests for added/modified behavior |
| Restructuring code | `/refactor` | Locks behavior with tests first, then refactors safely |
| Reviewing a diff or PR | `/pr-review` | Fans out to code/security/performance/doc reviewer agents |
| Ready to commit and open a PR | `/ship` | Scan → commit → push → PR, with confirmation per step |
| Onboarding or understanding unfamiliar code | `/explain` | Diagrams and mental models, not line-by-line narration |
| `.claude/` config doesn't match the codebase | `/setupdotclaude` | Rescans the stack and re-customizes rules/settings/this file |

### Design & frontend

Use these for **any** UI work — new screens, components, landing pages, redesigns, or "make this look better". Default order: `design-taste-frontend` or `impeccable` to set direction → build → `review-animations` / `impeccable` audit before calling it done.

| Situation | Use | Why |
|---|---|---|
| Building or redesigning any interface (landing page, dashboard, product UI, forms, empty states) | `/impeccable` | Broadest design skill: hierarchy, IA, a11y, responsive, typography, color, motion, UX copy. Its edit hooks also run automatically. **If no design context exists yet, run `/impeccable init` first.** |
| Landing pages, portfolios, marketing pages, redesigns | `/design-taste-frontend` | Anti-generic: infers a real design direction from the brief instead of shipping a template |
| Generating distinctive UI from scratch | `frontend-design` plugin / `frontend-designer` agent | Creates design tokens first, then components; anti-AI-slop aesthetics |
| Any decision about UI polish, component API, or "does this feel right" | `/emil-design-eng` | Emil Kowalski's design-engineering philosophy — the invisible details |
| Adding motion or a transition (web) | `/animate` | Decides *whether* to animate, then purpose, tool, properties, curve, duration, interruption, exit |
| Adding motion in React Native / Expo | `/animate-expo` | Same decisions with Reanimated, Gesture Handler, haptics |
| Reviewing motion code in a diff | `/review-animations` | High craft bar; flags by default |
| "What could be animated here?" / "make it feel alive" | `/find-animation-opportunities` | Read-only proposal with exact values — also rejects what shouldn't move |
| "Improve/audit the animations" across the app | `/improve-animations` | Prioritized audit plus implementation plans |
| Gesture-driven UI, springs, sheets, drag/swipe, translucent materials | `/apple-design` | Apple's fluid-motion and depth principles for the web |
| Choosing a library (charts, OTP, command menu, DnD, toasts, virtualization…) | `/pick-ui-library` | Curated, opinionated picks — avoids reinventing or picking a dead lib |
| Toasts / Sonner problems | `/ask-sonner` | Setup, promise toasts, theming, "toast behind modal" fixes |
| User can't decide between UI directions | `/prototype` | Builds several genuinely different versions behind a live picker |
| Naming a motion effect | `/animation-vocabulary` | Vague description → exact term |
| Writing or reviewing Swift | `/write-swift` | Swift 6 concurrency, value types, modern APIs |

### Review agents (`.claude/agents/`)

Delegate to these (in parallel where possible) before merging, or whenever the change touches their area — don't wait for `/pr-review`:

- `code-reviewer` — bugs: off-by-one, null derefs, inverted conditions, races, swallowed errors
- `security-reviewer` — any change touching auth, input handling, secrets, crypto, or data exposure
- `performance-reviewer` — DB queries, loops over large data, network calls, render paths
- `doc-reviewer` — when docs or public APIs change
- `frontend-designer` — when building UI (see Design & frontend)

### Tooling plugins

- **playwright** — use the browser tools to verify UI changes actually render and behave; screenshot before claiming a visual fix works
- **feature-dev** — `/feature-dev` for guided feature development with `code-explorer` / `code-architect` / `code-reviewer` agents on larger features

## Don'ts

- Don't modify generated files (`*.gen.ts`, `*.generated.*`)

## Maintaining This File

This `CLAUDE.md` was seeded from the dotclaude bootstrap and is now **this project's** instructions file. The agent working in this repo owns it:

- On first run, execute `/setupdotclaude` to replace the template sections above with the real stack, then remove every `> REPLACE:` block. Keep **Skills & Agents** and this section.
- Keep it current as the project evolves: record new **Key Decisions** (the *why*), **Domain Knowledge**, changed commands, and any new skills/agents added to `.claude/`. Prune entries that stop being true.
- Add project-specific guidance the moment it would have saved a mistake — conventions, gotchas, things the user corrected. Anything worth telling a new teammate on day one belongs here.
- Remove skill rows from the tables above that can't apply to this project (e.g. `animate-expo` in a web-only app, `write-swift` outside Swift) — every line costs tokens on every turn.
- `bash update.sh` pulls future dotclaude config updates; it does not overwrite this file.
