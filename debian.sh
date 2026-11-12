#!/bin/sh
# Root-level setup for a headless Debian 13 VM. Run once with sudo before
# ./install.sh. Debian-only; safe to re-run.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
[ -n "${SUDO_USER:-}" ] || { echo "run via sudo as the normal user, not as root directly" >&2; exit 1; }

# kitty-terminfo: ssh sessions from kitty arrive with TERM=xterm-kitty.
# build-essential: nvim-treesitter compiles parsers. ripgrep: telescope. unzip, nodejs, npm, golang-go: mason installs the nvim LSP
# servers and formatters (lsp.lua TOOLS) from zip, npm and go sources.
apt-get update
apt-get install -y git curl ca-certificates python3 jq fzf ripgrep kitty-terminfo \
  build-essential unzip nodejs npm golang-go

# Keeps the user systemd manager, the zitty snapshot timer and zmx sessions alive after ssh logout
loginctl enable-linger "$SUDO_USER"

# Each kitty split from the Mac is one ssh channel; the default of 10 caps the layout
echo "MaxSessions 64" > /etc/ssh/sshd_config.d/zitty.conf
# A socket-activated sshd cannot re-bind port 22 on reload; existing sessions survive the restart
systemctl restart ssh

echo "done; now run ./install.sh as $SUDO_USER"
