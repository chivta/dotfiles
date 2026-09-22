# If not running interactively, don't do anything
[[ $- != *i* ]] && return

WORDCHARS=''
bindkey "^U" backward-kill-line

backward-kill-space-then-word() {
  if [[ $LBUFFER =~ '[[:space:]]+$' ]]; then
    LBUFFER=${LBUFFER%$MATCH}
  else
    zle backward-kill-word
  fi
}
zle -N backward-kill-space-then-word
bindkey '^W' backward-kill-space-then-word
bindkey '^[^?' backward-kill-space-then-word
# --- ALIASES ---
alias cc='claude'
alias dc='docker-compose'
alias d='docker'
alias g='git'
alias nv='nvim'
alias grep='grep --color=auto'
alias sudp='sudo'
alias bc='bc -q'
alias ks='kubectl'
alias k='kubectl'

# macOS ships BSD ls (no --color=auto); use GNU coreutils' gls if installed
if command -v gls >/dev/null 2>&1; then
    alias ls='gls --color=auto'
    alias ll='gls -la --color=auto'
else
    alias ls='ls -G'
    alias ll='ls -laG'
fi

# Navigation & Safety
alias ..='cd ..'
alias ...='cd ../..'
# alias cp='cp -iv'
# alias mv='mv -iv'
# alias rm='rm -iv'
alias update='brew update && brew upgrade'

# --- GIT PROMPT SETUP ---
# curl -L https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -o ~/.git-prompt.sh
if [ -f "$HOME/.git-prompt.sh" ]; then
    source "$HOME/.git-prompt.sh"
fi

# --- ZSH HISTORY SETTINGS ---
HISTSIZE=1000
SAVEHIST=2000
HISTFILE="$HOME/.zsh_history"
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

# --- THE PROMPT ---
setopt PROMPT_SUBST

build_prompt() {
    local exit=$?

    local c_frame='%F{125}'   # Purple frame
    local c_user='%F{219}'    # Soft pink
    local c_host='%F{225}'    # Pale pink
    local c_dir='%F{219}'     # Soft pink
    local c_git='%F{120}'     # Mint green
    local c_err='%F{196}'     # Bright red error
    local c_symbol='%F{219}'  # Soft pink $
    local reset='%f'

    local err_display=""
    if [ "$exit" -ne 0 ]; then
        err_display=" ${c_err}${exit}${reset}"
    fi

    local git_status=""
    if command -v __git_ps1 >/dev/null 2>&1; then
        git_status="${c_git}$(__git_ps1 '(%s)')${reset}"
    fi

    PROMPT="${c_frame}┌──${c_frame}[${c_user}%n${c_frame}@${c_host}%m ${c_dir}%1~${c_frame}] ${git_status}${reset}${err_display}
${c_frame}└─${c_symbol}\$${reset} "
}
precmd_functions+=(build_prompt)

# --- TOOLS ---
# FZF keybindings + completion (installed via: brew install fzf)
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --zsh)"
fi

# --- CUSTOM FUNCTIONS ---
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Auto-attach tmux on SSH login
if [[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
    tmux attach-session -t main || tmux new-session -s main
fi


cd ~

