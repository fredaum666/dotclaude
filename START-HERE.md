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

---

Bootstrap handles everything:
- `.claude/` config committed to your repo
- `upstream` remote → dotclaude (for future updates)
- GitHub repo creation or connection
- Plugins: superpowers, frontend-design, playwright, feature-dev

Once done, open Claude Code and run `/setupdotclaude` to tailor the config to your stack.
