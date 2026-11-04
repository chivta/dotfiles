#!/bin/sh
# Symlinks dotfiles into place for the current OS and installs tmux plugins and
# the pinned zitty release. On Linux it also installs pinned zmx, neovim and the
# tree-sitter CLI, links the Hyprland configs only when Hyprland is present, and
# registers the zitty Claude Code hooks. On Debian run ./debian.sh (root) first.
# Safe to re-run. A real file/dir already at a target is moved to <target>.bak
# first, since `ln -sfn` onto a real directory would link inside it.
set -eu

DOT="$(cd "$(dirname "$0")" && pwd)"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"
ZITTY_VERSION="v0.1.1"
ZITTY_DIR="$HOME/.local/share/zitty"
ZITTY_URL="https://github.com/chivta/zitty/archive/refs/tags/$ZITTY_VERSION.tar.gz"
# zmx upgrades kill every running session, so it is pinned and never auto-upgraded
ZMX_VERSION="0.8.1"
ZMX_DIR="$HOME/.local/share/zmx"
ZMX_URL="https://zmx.sh/a/zmx-$ZMX_VERSION-linux-x86_64.tar.gz"
NVIM_VERSION="v0.12.6"
NVIM_DIR="$HOME/.local/share/neovim"
NVIM_URL="https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-x86_64.tar.gz"
TREE_SITTER_VERSION="v0.27.1"
TREE_SITTER_DIR="$HOME/.local/share/tree-sitter"
TREE_SITTER_URL="https://github.com/tree-sitter/tree-sitter/releases/download/$TREE_SITTER_VERSION/tree-sitter-linux-x64.gz"
SHARED_CONFIGS="bash kitty nvim git tmux"
# Codex and pi read the same instructions and skills as Claude Code
AGENT_HOMES="$HOME/.codex $HOME/.pi/agent"

missing=""
for cmd in git curl tar python3 tmux jq; do
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done
if [ -n "$missing" ]; then
  echo "missing required commands:$missing" >&2
  [ "$(uname -s)" = Linux ] && echo "on Debian run: sudo ./debian.sh" >&2
  exit 1
fi

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

# fetch_tarball <url> <version dir> <strip components>
# Upgrading is a version bump and a re-run; existing version dirs are kept.
# Extracted in a temp dir so a failed download never leaves a half-filled one.
fetch_tarball() {
  [ -d "$2" ] && return
  mkdir -p "$(dirname "$2")"
  fetch_tmp=$(mktemp -d "$(dirname "$2")/.tmp.XXXXXX")
  curl -fsSL "$1" | tar xz --strip-components="$3" -C "$fetch_tmp"
  mv "$fetch_tmp" "$2"
}

# fetch_gz_binary <url> <version dir> <binary name>
# Same temp-dir rule as fetch_tarball, for a single gzipped binary.
fetch_gz_binary() {
  [ -d "$2" ] && return
  mkdir -p "$(dirname "$2")"
  fetch_tmp=$(mktemp -d "$(dirname "$2")/.tmp.XXXXXX")
  curl -fsSL "$1" | gunzip > "$fetch_tmp/$3"
  chmod +x "$fetch_tmp/$3"
  mv "$fetch_tmp" "$2"
}

fetch_tarball "$ZITTY_URL" "$ZITTY_DIR/$ZITTY_VERSION" 1
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
    if command -v Hyprland >/dev/null 2>&1; then
      link hypr "$HOME/.config/hypr"
      link waybar "$HOME/.config/waybar"
    fi
    # The Mac gets these from brew
    fetch_tarball "$ZMX_URL" "$ZMX_DIR/$ZMX_VERSION" 0
    link "$ZMX_DIR/$ZMX_VERSION/zmx" "$HOME/.local/bin/zmx"
    fetch_tarball "$NVIM_URL" "$NVIM_DIR/$NVIM_VERSION" 1
    link "$NVIM_DIR/$NVIM_VERSION/bin/nvim" "$HOME/.local/bin/nvim"
    # nvim-treesitter main needs CLI >= 0.26.1, Debian ships 0.22.6
    fetch_gz_binary "$TREE_SITTER_URL" "$TREE_SITTER_DIR/$TREE_SITTER_VERSION" tree-sitter
    link "$TREE_SITTER_DIR/$TREE_SITTER_VERSION/tree-sitter" "$HOME/.local/bin/tree-sitter"
    for f in zitty-host zitty-claude-hook; do
      link "$ZITTY_DIR/current/$f" "$HOME/.local/bin/$f"
    done
    # Registers zitty's session hooks; an exact-command match keeps re-runs a no-op
    mkdir -p "$HOME/.claude"
    [ -f "$HOME/.claude/settings.json" ] || echo '{}' > "$HOME/.claude/settings.json"
    python3 - "$HOME/.claude/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
settings = json.load(open(path, encoding="utf-8"))
hooks = settings.setdefault("hooks", {})
for event, arg in (("SessionStart", "start"), ("SessionEnd", "end")):
    command = f"~/.local/bin/zitty-claude-hook {arg}"
    entries = hooks.setdefault(event, [])
    if not any(h.get("command") == command for e in entries for h in e.get("hooks", [])):
        entries.append({"hooks": [{"type": "command", "command": command}]})
with open(path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY
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
