# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# --- OS-SPECIFIC ---
# GOPATH must be exported before env.sh, which only defaults it when unset.
case "$(uname -s)" in
    Darwin)
        # macOS ships BSD ls (no --color=auto); use GNU coreutils' gls if installed
        if command -v gls >/dev/null 2>&1; then
            alias ls='gls --color=auto'
            alias ll='gls -la --color=auto'
        else
            alias ls='ls -G'
            alias ll='ls -laG'
        fi

        alias update='brew update && brew upgrade'

        # Added by OrbStack: command-line tools and integration
        # This won't be added again if you remove it.
        source ~/.orbstack/shell/init.bash 2>/dev/null || :
        ;;
    Linux)
        export GOPATH='/opt/go-workspace'
        export LIBVIRT_DEFAULT_URI="qemu:///system"
        export __NV_DISABLE_EXPLICIT_SYNC=1

        alias ll='ls -la --color=auto'
        alias ls='ls --color=auto'
        alias update='sudo pacman -Syu'
        alias virst=virsh
        alias hyperctl='hyprctl'
        alias lg='looking-glass-client -F'
        # Wayland fix for VS Code
        alias code='code --enable-features=UseOzonePlatform --ozone-platform=wayland'
        ;;
esac

# --- EXPORTS & PATHS ---
source "$HOME/.config/shell/env.sh"

# --- ALIASES ---
# Shared aliases, functions, git prompt and SSH tmux attach
source "$HOME/.config/shell/rc.sh"

# --- KEYBINDS ---
# Readline would otherwise rebind ^W to the tty's werase and ignore the bind -x below
bind 'set bind-tty-special-chars off'

# ^W: delete only trailing whitespace if there is any, else a word like backward-kill-word
_backward_kill_space_then_word() {
    local left=${READLINE_LINE:0:READLINE_POINT}
    local right=${READLINE_LINE:READLINE_POINT}
    if [[ $left =~ [[:space:]]+$ ]]; then
        left=${left%"${BASH_REMATCH[0]}"}
    elif [[ $left =~ [[:alnum:]]*[^[:alnum:]]*$ ]]; then
        left=${left%"${BASH_REMATCH[0]}"}
    fi
    READLINE_LINE=$left$right
    READLINE_POINT=${#left}
}
bind -x '"\C-w": _backward_kill_space_then_word'

# alt+backspace: delete one run of whitespace, letters/digits or punctuation
_backward_kill_run() {
    local left=${READLINE_LINE:0:READLINE_POINT}
    local right=${READLINE_LINE:READLINE_POINT}
    local re='([[:space:]]+|[[:alnum:]]+|[^[:alnum:][:space:]]+)$'
    [[ $left =~ $re ]] || return
    left=${left%"${BASH_REMATCH[0]}"}
    READLINE_LINE=$left$right
    READLINE_POINT=${#left}
}
bind -x '"\e\C-?": _backward_kill_run'

# alt+right: stop at word and punctuation boundaries, skipping only whitespace
_forward_word_stop_at_punct() {
    local re='^([[:alnum:]]+|[^[:alnum:][:space:]]+)?[[:space:]]*'
    [[ ${READLINE_LINE:READLINE_POINT} =~ $re ]] && (( READLINE_POINT += ${#BASH_REMATCH[0]} ))
}
bind -x '"\ef": _forward_word_stop_at_punct'

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

    local MARK_A=""
    [[ -n $TMUX ]] && MARK_A='\[\e]133;A\e\\\]'

    export PS1="${MARK_A}${LINE_1}\n${LINE_2}"
}

PROMPT_COMMAND=build_prompt

# Inside tmux, mark each prompt (OSC 133;A, added by build_prompt) and the start
# of each command's output (OSC 133;C). tmux's copy mode jumps between them, and
# kitmux's cmd+shift+c uses that to copy the last command's output. Plain kitty
# tabs get these marks from kitty's own shell integration, so this stays tmux-only.
[[ -n $TMUX ]] && PS0='\e]133;C\e\\'

# --- TOOLS ---
# FZF keybindings + completion (installed via: brew install fzf or pacman -S fzf)
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
fi
