#!/bin/bash
# Sends a desktop notification when Claude Code needs attention.
# Used as a Notification hook.

MESSAGE="Claude Code needs your attention"
TITLE="Claude Code"

if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$TITLE" "$MESSAGE"
fi

exit 0
