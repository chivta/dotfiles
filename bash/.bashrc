# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# --- EXPORTS & PATHS ---
export GOPATH='/opt/go-workspace'
source "$HOME/.config/shell/env.sh"
export LIBVIRT_DEFAULT_URI="qemu:///system"
export __NV_DISABLE_EXPLICIT_SYNC=1

# --- ALIASES ---
# Shared aliases, functions, git prompt and SSH tmux attach
source "$HOME/.config/shell/rc.sh"

alias ll='ls -la --color=auto'
alias ls='ls --color=auto'
alias update='sudo pacman -Syu'
alias virst=virsh
alias hyperctl='hyprctl'
alias lg='looking-glass-client -F'
# Wayland fix for VS Code
alias code='code --enable-features=UseOzonePlatform --ozone-platform=wayland'

# --- BASH SETTINGS ---
shopt -s histappend
shopt -s checkwinsize
HISTSIZE=1000
HISTFILESIZE=2000

# --- THE PROMPT ---
build_prompt() {
    local EXIT="$?"

    # Color Palette (Pink/Purple/Dark Red)
    local C_FRAME="\[\e[38;5;125m\]"   # Purple frame
    local C_BRACKET="\[\e[38;5;125m\]" # Match frame
    local C_USER="\[\e[38;5;219m\]"    # Soft pink
    local C_AT="\[\e[38;5;125m\]"      # Match frame
    local C_HOST="\[\e[38;5;225m\]"    # Pale pink
    local C_DIR="\[\e[38;5;219m\]"     # Soft pink
    local C_GIT="\[\e[38;5;120m\]"     # Mint green
    local C_ERR="\[\e[38;5;196m\]"     # Bright red error
    local C_SYMBOL="\[\e[38;5;219m\]"  # Soft pink $
    local RESET="\[\e[m\]"

    local ERR_DISPLAY=""
    if [ "$EXIT" -ne 0 ]; then
        ERR_DISPLAY=" ${C_ERR}${EXIT}${RESET}"
    fi

    local LINE_1="${C_FRAME}┌──${C_BRACKET}[${C_USER}\u${C_AT}@${C_HOST}\h ${C_DIR}\W${C_BRACKET}] ${C_GIT}\$(__git_ps1 '(%s)')${RESET}${ERR_DISPLAY}"
    local LINE_2="${C_FRAME}└─${C_SYMBOL}\$${RESET} "

    export PS1="${LINE_1}\n${LINE_2}"
}

PROMPT_COMMAND=build_prompt

# --- TOOLS ---
# FZF keybindings + completion (installed via: pacman -S fzf)
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
fi
