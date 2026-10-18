#!/bin/bash
# Runs the agent-delegation eval suite. Extra arguments go to `claude plugin eval`.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_SRC=$HERE/../../skills/agent-delegation
CLAUDE_MD=$HERE/../../CLAUDE.md
cd "$HERE"

# A plugin cannot hold a symlink out of its directory, so the skill is copied
rm -rf skills/agent-delegation
mkdir -p skills
cp -R "$SKILL_SRC" skills/agent-delegation

# The suite re-validates the real setup, so every case must carry the current Delegation paragraph
expected=$(awk '/^## Delegation$/ {found=1; next} found && NF {print; exit}' "$CLAUDE_MD")
[ -n "$expected" ] || { echo "no Delegation paragraph in $CLAUDE_MD" >&2; exit 1; }

stale=0
for prompt in evals/*/prompt.md; do
  actual=$(sed -n "s/^append_system_prompt: '\(.*\)'\$/\1/p" "$prompt" | sed "s/''/'/g")
  if [ "$actual" != "$expected" ]; then
    echo "stale append_system_prompt in $prompt" >&2
    stale=1
  fi
done
[ "$stale" -eq 0 ] || { echo "update the cases to match the Delegation section of $CLAUDE_MD" >&2; exit 1; }

exec claude plugin eval . --trust-plugin --scaffold --allow-tools Write Edit --model opus "$@"
