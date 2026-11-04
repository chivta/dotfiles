#!/bin/sh
set -eu

REPO=$(CDPATH='' cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/pi-plugin-links.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
# install.sh links $HOME/.config/kitty to the repo's kitty dir and then writes the
# zitty links into it, so a run against the real checkout would point the
# machine's kitty config at this temp dir.
cp -R "$REPO" "$TMP/dot"
rm -rf "$TMP/dot/.git"
DOT=$(cd "$TMP/dot" && pwd)
export HOME="$TMP/home"
mkdir -p "$HOME/bin" "$HOME/.pi/agent/claude-plugins/figma" "$HOME/.claude/plugins/cache/figma/active-v1" "$HOME/.claude/plugins/cache/figma/active-v2" "$HOME/.claude/plugins/cache/playwright/active" "$HOME/.tmux"
printf 'preserve backup\n' > "$HOME/.pi/agent/claude-plugins/figma/original"
printf '{"keep":true}\n' > "$HOME/.pi/agent/settings.json"
printf 'keep auth\n' > "$HOME/.pi/agent/mcp-auth.json"

cat > "$HOME/bin/git" <<'SH'
#!/bin/sh
[ "$1" = clone ] || exit 1
mkdir -p "$3/bin"
printf '#!/bin/sh\nexit 0\n' > "$3/bin/install_plugins"
chmod +x "$3/bin/install_plugins"
SH
chmod +x "$HOME/bin/git"
export PATH="$HOME/bin:$PATH"

for plugin_dir in "$HOME"/.claude/plugins/cache/*/*; do
  name=$(basename "$(dirname "$plugin_dir")")
  [ "$name" = figma ] && server=figma || server=playwright
  printf '{"%s":{"command":"fixture","args":[]}}\n' "$server" > "$plugin_dir/.mcp.json"
done
write_installed_plugins() {
  python3 - "$HOME/.claude/plugins/installed_plugins.json" "$1" <<'PY'
import json, sys
path, figma_path = sys.argv[1:]
json.dump({"plugins": {
    "figma@claude-plugins-official": [{"scope": "user", "installPath": figma_path}],
    "playwright@anthropic-plugin-directory": [{"scope": "user", "installPath": figma_path.replace("/figma/", "/playwright/").replace("active-v1", "active")}],
}}, open(path, "w", encoding="utf-8"))
PY
}
assert_links() {
  python3 - "$HOME" "$DOT" "$1" <<'PY'
import os, sys
home, dot, figma = sys.argv[1:]
checks = {
    os.path.join(home, ".pi/agent/claude-plugins/figma"): figma,
    os.path.join(home, ".pi/agent/claude-plugins/playwright"): os.path.join(home, ".claude/plugins/cache/playwright/active"),
    os.path.join(home, ".pi/agent/mcp-adapter.json"): os.path.join(dot, "pi/mcp-adapter.json"),
}
for link, source in checks.items():
    assert os.path.islink(link), f"not a symlink: {link}"
    assert os.readlink(link) == source, f"wrong link target for {link}: {os.readlink(link)} != {source}"
    assert os.path.realpath(link) == os.path.realpath(source), f"broken symlink: {link}"
    assert os.path.exists(link), f"missing symlink source: {link}"
PY
}

write_installed_plugins "$HOME/.claude/plugins/cache/figma/active-v1"
"$DOT/install.sh" >/dev/null
assert_links "$HOME/.claude/plugins/cache/figma/active-v1"
test "$(cat "$HOME/.pi/agent/claude-plugins/figma.bak/original")" = 'preserve backup'
test "$(cat "$HOME/.pi/agent/settings.json")" = '{"keep":true}'
test "$(cat "$HOME/.pi/agent/mcp-auth.json")" = 'keep auth'
"$DOT/install.sh" >/dev/null
assert_links "$HOME/.claude/plugins/cache/figma/active-v1"
write_installed_plugins "$HOME/.claude/plugins/cache/figma/active-v2"
"$DOT/install.sh" >/dev/null
assert_links "$HOME/.claude/plugins/cache/figma/active-v2"
test "$(cat "$HOME/.pi/agent/settings.json")" = '{"keep":true}'
test "$(cat "$HOME/.pi/agent/mcp-auth.json")" = 'keep auth'
printf '%s\n' 'passed: absolute plugin sources resolve; rerun is stable; active path updates; adapter config link and backups/state verified'
