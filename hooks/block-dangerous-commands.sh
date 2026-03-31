#!/bin/bash
# Blocks dangerous shell commands: push to main, force push, destructive operations.
# Used as a PreToolUse hook for Bash operations.
# Exit 2 = block the action. Exit 0 = allow.

# Requires jq for JSON parsing — fail closed if missing
if ! command -v jq >/dev/null 2>&1; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"jq is required for command protection hooks but is not installed.\"}}"
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

deny() {
  local reason
  reason=$(jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}')
  echo "$reason"
  exit 2
}

# ──────────────────────────────────────────────
# Git protections
# ──────────────────────────────────────────────

# Check if the command contains git push (handles chaining with &&, ;, |, subshells)
if echo "$COMMAND" | grep -qE '(^|[;&|()]+[[:space:]]*)git[[:space:]]+push'; then

  # Block push to main or master (covers: origin main, origin HEAD:main, origin refs/heads/main, origin main:main)
  if echo "$COMMAND" | grep -qE 'git[[:space:]]+push[[:space:]].*([[:space:]]|:)(main|master)(\b|$)'; then
    deny "Blocked: cannot push directly to main/master. Use a feature branch and create a PR."
  fi

  # Block bare "git push" or "git push <remote>" (no explicit branch) when on main/master
  # Covers: git push, git push origin, git push upstream — but NOT git push origin feature-branch
  if echo "$COMMAND" | grep -qE 'git[[:space:]]+push([[:space:]]+[a-zA-Z0-9_.-]+)?[[:space:]]*($|[;&|])'; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
    if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
      deny "Blocked: you are on $CURRENT_BRANCH. Use a feature branch and create a PR."
    fi
  fi

  # Block force push (allow --force-with-lease)
  if echo "$COMMAND" | grep -qE 'git[[:space:]]+push.*(-[a-zA-Z]*f|--force)([[:space:]]|$)' && ! echo "$COMMAND" | grep -q '\-\-force-with-lease'; then
    deny "Blocked: force push is not allowed. Use --force-with-lease if you need to overwrite remote."
  fi
fi

# ──────────────────────────────────────────────
# Destructive filesystem operations
# ──────────────────────────────────────────────

# Block rm targeting root, home, or parent paths — covers:
#   rm -rf /, rm -fr ~, rm -r -f /, rm --recursive --force /, rm -rf -- /path
# Strategy: if the command contains rm AND (recursive flag) AND (force flag) AND a dangerous target,
# or if it targets / or ~ in any rm invocation regardless of flags (belt-and-suspenders).
if echo "$COMMAND" | grep -qE '\brm\b'; then
  # Long-form or short-form recursive+force targeting dangerous paths
  if echo "$COMMAND" | grep -qE '\brm\b.*(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r|--recursive|--force|-r[[:space:]]+-f|-f[[:space:]]+-r)' && \
     echo "$COMMAND" | grep -qE '(\/[[:space:]]|\/\*|\/\s*$|~[\/\*[:space:]]|~$|\$HOME[\/[:space:]]|\$HOME$|\.\.\/)'; then
    deny "Blocked: recursive force-delete on root/home/parent paths. Specify a safe target directory."
  fi
  # Belt-and-suspenders: any rm on / or ~ regardless of flags
  if echo "$COMMAND" | grep -qE '\brm\b.*[[:space:]](\/[[:space:]]|\/\*|\/\s*$|~[\/\*]?[[:space:]]|~[\/\*]?$)'; then
    deny "Blocked: rm targeting root or home directory is not allowed."
  fi
fi

# ──────────────────────────────────────────────
# Dangerous database operations
# ──────────────────────────────────────────────

# Block DROP TABLE/DATABASE without safeguards
if echo "$COMMAND" | grep -qiE 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)[[:space:]]'; then
  deny "Blocked: DROP TABLE/DATABASE/SCHEMA detected. This is destructive and irreversible. Run manually if intended."
fi

# Block DELETE FROM without WHERE
if echo "$COMMAND" | grep -qiE 'DELETE[[:space:]]+FROM[[:space:]]+[a-zA-Z_]+[[:space:]]*($|;)' && ! echo "$COMMAND" | grep -qiE 'WHERE'; then
  deny "Blocked: DELETE FROM without WHERE clause would delete all rows. Add a WHERE clause."
fi

# Block TRUNCATE TABLE
if echo "$COMMAND" | grep -qiE 'TRUNCATE[[:space:]]+TABLE'; then
  deny "Blocked: TRUNCATE TABLE detected. This is destructive and irreversible. Run manually if intended."
fi

# ──────────────────────────────────────────────
# Dangerous system commands
# ──────────────────────────────────────────────

# Block chmod 777
if echo "$COMMAND" | grep -qE 'chmod[[:space:]]+777'; then
  deny "Blocked: chmod 777 gives everyone read/write/execute. Use more restrictive permissions (e.g., 755 or 644)."
fi

# Block piping curl/wget directly to a shell or interpreter
if echo "$COMMAND" | grep -qE '(curl|wget)[[:space:]].*\|[[:space:]]*(bash|sh|zsh|fish|dash|python[23]?|perl|ruby|node|nodejs|sudo)'; then
  deny "Blocked: piping downloaded content directly to an interpreter is dangerous. Download first, inspect, then execute."
fi

# Block download-then-execute pattern: curl/wget -o <file> && <shell> <file>
if echo "$COMMAND" | grep -qE '(curl|wget)[[:space:]].*-[oO][[:space:]]' && \
   echo "$COMMAND" | grep -qE '(&&|;)[[:space:]]*(bash|sh|zsh|fish|dash|python[23]?|perl|ruby|node|nodejs|sudo|source|\.)'; then
  deny "Blocked: downloading a file then executing it is dangerous. Inspect the downloaded content before running."
fi

# Block disk/partition destructive commands
# Note: exclude >/dev/null (common redirect) — only block writes to real devices like /dev/sda
if echo "$COMMAND" | grep -qE '(mkfs|dd[[:space:]]+if=)'; then
  deny "Blocked: destructive disk operation detected. This can cause irreversible data loss."
fi
if echo "$COMMAND" | grep -qE '>[[:space:]]*/dev/[a-z]+[0-9]'; then
  deny "Blocked: writing directly to a disk device. This can cause irreversible data loss."
fi

# ──────────────────────────────────────────────
# Destructive git operations
# ──────────────────────────────────────────────

# Block git reset --hard (loses uncommitted work permanently)
if echo "$COMMAND" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
  deny "Blocked: git reset --hard discards uncommitted changes permanently. Use git stash or git reset --soft instead."
fi

# Block git clean -f (permanently deletes untracked files)
if echo "$COMMAND" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f'; then
  deny "Blocked: git clean -f permanently deletes untracked files. Review with git clean -n first, then run manually if intended."
fi

# ──────────────────────────────────────────────
# Accidental package publishing
# ──────────────────────────────────────────────

if echo "$COMMAND" | grep -qE '(npm|yarn|pnpm|bun)[[:space:]]+publish'; then
  deny "Blocked: publishing npm packages should be done manually or via CI, not through Claude Code."
fi

if echo "$COMMAND" | grep -qE 'cargo[[:space:]]+publish'; then
  deny "Blocked: publishing crates should be done manually or via CI, not through Claude Code."
fi

if echo "$COMMAND" | grep -qE 'gem[[:space:]]+push'; then
  deny "Blocked: publishing gems should be done manually or via CI, not through Claude Code."
fi

if echo "$COMMAND" | grep -qE 'twine[[:space:]]+upload'; then
  deny "Blocked: publishing Python packages should be done manually or via CI, not through Claude Code."
fi

exit 0
