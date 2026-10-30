#!/bin/sh
# Symlinks dotfiles into place for the current OS and installs tmux plugins.
# Safe to re-run. A real file/dir already at a target is moved to <target>.bak
# first, since `ln -sfn` onto a real directory would link inside it.
set -eu

DOT="$(cd "$(dirname "$0")" && pwd)"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"
ZITTY_VERSION="v0.1.0"
ZITTY_DIR="$HOME/.local/share/zitty"
ZITTY_URL="https://github.com/chivta/zitty/archive/refs/tags/$ZITTY_VERSION.tar.gz"
SHARED_CONFIGS="bash kitty nvim git tmux"
# Codex and pi read the same instructions and skills as Claude Code
AGENT_HOMES="$HOME/.codex $HOME/.pi/agent"

# link <repo-relative or absolute source> <target>
link() {
  case "$1" in
    /*) source=$1 ;;
    *) source=$DOT/$1 ;;
  esac
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    mv "$2" "$2.bak"
    echo "moved $2 -> $2.bak"
  fi
  mkdir -p "$(dirname "$2")"
  ln -sfn "$source" "$2"
  echo "linked $2 -> $source"
}

for d in $SHARED_CONFIGS; do link "$d" "$HOME/.config/$d"; done
link bash/.bashrc "$HOME/.bashrc"
link bash/.bash_profile "$HOME/.bash_profile"

# Only these entries are linked, the rest of ~/.claude, ~/.codex and ~/.pi/agent
# is runtime state the agents write themselves. settings.json stays per-machine.
link claude/CLAUDE.md "$HOME/.claude/CLAUDE.md"
link claude/skills "$HOME/.claude/skills"
link claude/hooks "$HOME/.claude/hooks"
# Pi's adapter config is tracked separately from its machine-owned settings/auth state.
link pi/mcp-adapter.json "$HOME/.pi/agent/mcp-adapter.json"

# Point Pi at Claude's active user-installed MCP plugins without copying bundles.
# installed_plugins.json records the active installation paths; the stable aliases
# keep those machine-specific version paths out of tracked configuration.
link_claude_plugin() {
  plugin_id=$1
  alias_name=$2
  target="$HOME/.pi/agent/claude-plugins/$alias_name"
  if command -v python3 >/dev/null 2>&1 && [ -f "$HOME/.claude/plugins/installed_plugins.json" ]; then
    source_path=$(python3 - "$HOME/.claude/plugins/installed_plugins.json" "$plugin_id" <<'PY'
import json, sys
try:
    plugins = json.load(open(sys.argv[1], encoding="utf-8")).get("plugins", {})
    installs = plugins.get(sys.argv[2], [])
    for item in installs:
        if item.get("scope") == "user" and isinstance(item.get("installPath"), str):
            print(item["installPath"])
            break
except (OSError, ValueError, TypeError):
    pass
PY
)
    if [ -n "$source_path" ] && [ -d "$source_path" ] && [ -f "$source_path/.mcp.json" ]; then
      link "$source_path" "$target"
      return
    fi
  fi
  echo "skipped missing active Claude MCP plugin: $plugin_id"
}
link_claude_plugin figma@claude-plugins-official figma
link_claude_plugin playwright@anthropic-plugin-directory playwright
for a in $AGENT_HOMES; do
  link claude/CLAUDE.md "$a/AGENTS.md"
  link claude/skills "$a/skills"
done

# claude-wrap lets Cmd+V paste images into Claude Code over SSH
link claude-clipboard-ssh/claude-wrap "$HOME/.local/bin/claude-wrap"

# Upgrading is a version bump and a re-run; existing version dirs are kept.
# Extracted in a temp dir so a failed download never leaves a half-filled one.
if [ ! -d "$ZITTY_DIR/$ZITTY_VERSION" ]; then
  mkdir -p "$ZITTY_DIR"
  zitty_tmp=$(mktemp -d "$ZITTY_DIR/.tmp.XXXXXX")
  curl -fsSL "$ZITTY_URL" | tar xz --strip-components=1 -C "$zitty_tmp"
  mv "$zitty_tmp" "$ZITTY_DIR/$ZITTY_VERSION"
fi
link "$ZITTY_DIR/$ZITTY_VERSION" "$ZITTY_DIR/current"
link "$ZITTY_DIR/current/zitty" "$HOME/.local/bin/zitty"
for f in zitty.py zitty_layout.py zitty.conf; do
  link "$ZITTY_DIR/current/$f" "$HOME/.config/kitty/$f"
done

case "$(uname -s)" in
  Darwin)
    link karabiner "$HOME/.config/karabiner"
    link "$ZITTY_DIR/current/zitty-macos.conf" "$HOME/.config/kitty/zitty-macos.conf"
    ;;
  Linux)
    # xclip stub serves the pasted image to Claude Code; macOS needs none
    link claude-clipboard-ssh/xclip "$HOME/.local/bin/xclip"
    link fish "$HOME/.config/fish"
    link hypr "$HOME/.config/hypr"
    link waybar "$HOME/.config/waybar"
    for f in zitty-host zitty-claude-hook; do
      link "$ZITTY_DIR/current/$f" "$HOME/.local/bin/$f"
    done
    for f in zitty-linux.conf zitty-home.conf zitty-home.session; do
      link "$ZITTY_DIR/current/$f" "$HOME/.config/kitty/$f"
    done
    for f in zitty-snapshot.service zitty-snapshot.timer; do
      link "$ZITTY_DIR/current/systemd/$f" "$HOME/.config/systemd/user/$f"
    done
    systemctl --user daemon-reload
    systemctl --user enable --now zitty-snapshot.timer
    ;;
esac

[ -d "$TPM_DIR" ] || git clone "$TPM_REPO" "$TPM_DIR"
# Clones the @plugin entries (resurrect, continuum). Cloning TPM alone doesn't.
"$TPM_DIR/bin/install_plugins"
