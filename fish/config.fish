# Mirrors the exports in bash/.bashrc, which fish can't source
set -gx GOPATH /opt/go-workspace
fish_add_path --global --path --move $HOME/.local/bin $HOME/.local/npm/bin $HOME/.cargo/bin $HOME/.tfenv/bin $GOPATH/bin
set -gx PAGER less
set -gx LESS '-RF --mouse'
set -gx DFT_BYTE_LIMIT 500000
set -gx KUBECONFIG $HOME/.kube/config
set -gx LIBVIRT_DEFAULT_URI qemu:///system
set -gx __NV_DISABLE_EXPLICIT_SYNC 1

if status is-interactive
    set -g fish_greeting

    # .bashrc is bash syntax, but its top-level alias lines are valid fish
    string match -r '^alias .*' <$HOME/.config/bash/.bashrc | source
    command -q claude-wrap; and alias claude=claude-wrap

    alias ll='ls -la --color=auto'
    alias ls='ls --color=auto'
    alias update='sudo pacman -Syu'
    alias virst=virsh
    alias hyperctl='hyprctl'
    alias lg='looking-glass-client -F'
    alias code='code --enable-features=UseOzonePlatform --ozone-platform=wayland'

    if command -q fzf
        fzf --fish | source
    end
end
