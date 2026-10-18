#!/usr/bin/env bash
# Claude Code status line command: saves the rate limits it is piped for claude-usage.sh. Prints nothing.

OUT_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage

mkdir -p "$OUT_DIR" 2>/dev/null
tmp=$(mktemp "$OUT_DIR/.rate-limits.XXXXXX" 2>/dev/null) || exit 0

# Same-dir temp file + rename: several Claude Code sessions can run this at once.
if jq -c --argjson now "$(date +%s)" \
    '(.rate_limits // {}) | {five_hour, seven_day} | with_entries(select(.value != null))
     | select(length > 0) | . + {saved_at: $now}' >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv -f "$tmp" "$OUT_DIR/rate-limits.json"
else
    rm -f "$tmp"
fi
exit 0
