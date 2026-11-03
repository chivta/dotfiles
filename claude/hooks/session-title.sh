#!/bin/sh
# Claude Code UserPromptSubmit hook: renames the session, and with it the
# terminal tab, to the text in $TMPDIR/claude-session-title-<session id>.
# Hooks can set the title only on SessionStart and UserPromptSubmit, so a name
# that a skill picks mid-turn has to wait for the next prompt in this file.
f="${TMPDIR:-/tmp}/claude-session-title-$(jq -r .session_id)"
[ -f "$f" ] || exit 0
jq -nc --arg t "$(cat "$f")" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
rm -f "$f"
