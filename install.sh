#!/bin/sh
# Symlinks dotfiles into place for the current OS and installs tmux plugins.
# Safe to re-run. A real file/dir already at a target is moved to <target>.bak
# first, since `ln -sfn` onto a real directory would link inside it.
set -eu

DOT="$(cd "$(dirname "$0")" && pwd)"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"
SHARED_CONFIGS="shell kitty nvim git tmux"

# link <repo path> <target>
link() {
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    mv "$2" "$2.bak"
    echo "moved $2 -> $2.bak"
  fi
  mkdir -p "$(dirname "$2")"
  ln -sfn "$DOT/$1" "$2"
  echo "linked $2 -> $DOT/$1"
}

for d in $SHARED_CONFIGS; do link "$d" "$HOME/.config/$d"; done

case "$(uname -s)" in
  Darwin)
    link zsh/.zshenv "$HOME/.zshenv"
    link zsh "$HOME/.config/zsh"
    link karabiner "$HOME/.config/karabiner"
    ;;
  Linux)
    link bash/.bashrc "$HOME/.bashrc"
    link bash/.bash_profile "$HOME/.bash_profile"
    link hypr "$HOME/.config/hypr"
    link waybar "$HOME/.config/waybar"
    ;;
esac

[ -d "$TPM_DIR" ] || git clone "$TPM_REPO" "$TPM_DIR"
# Clones the @plugin entries (resurrect, continuum). Cloning TPM alone doesn't.
"$TPM_DIR/bin/install_plugins"
