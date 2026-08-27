# Start Here

## New project

Run from any empty or non-git directory:

```bash
curl -fsSL https://raw.githubusercontent.com/fredaum666/dotclaude/main/bootstrap.sh -o bootstrap.sh && bash bootstrap.sh
```

## Existing project

Run from inside your project folder:

```bash
cd your-project
curl -fsSL https://raw.githubusercontent.com/fredaum666/dotclaude/main/bootstrap.sh -o bootstrap.sh && bash bootstrap.sh
```

## Pull config updates

After dotclaude gets fixes or improvements, propagate them to any project:

```bash
cd your-project
bash update.sh
```

Adds new rules/skills/agents, keeps files you customized, never touches `CLAUDE.md`, then offers to install new plugins and community skills. If your `update.sh` predates Aug 2026 and exits silently after `y`, fetch the fixed copy first: `git fetch upstream main && git checkout upstream/main -- update.sh bootstrap.sh`

---

Bootstrap handles everything:
- `.claude/` config committed to your repo
- `upstream` remote → dotclaude (for future updates)
- GitHub repo creation or connection
- Plugins: superpowers, frontend-design, playwright, feature-dev
- Community skills (via `npx skills add`): design-taste-frontend from [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill), and all design-engineering skills from [emilkowalski/skill](https://github.com/emilkowalski/skill)
- [Impeccable](https://impeccable.style) design skill + hooks (`npx impeccable install`)
- [Context7](https://context7.com) MCP for live library docs (`npx ctx7 setup`) — sign in once via `/mcp`

Once done, open Claude Code and run `/setupdotclaude` to tailor the config to your stack, then `/impeccable init` to set up design context.
