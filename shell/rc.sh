# Interactive setup shared by zsh (macOS) and bash (Arch), sourced from
# .zshrc / .bashrc after their interactive-shell guard. Shell-specific bits
# (keybinds, prompt, history, ls flags) stay in those files.

# --- ALIASES ---
alias c='claude'
alias cc='claude'
alias ccc='claude --continue'
alias dc='docker-compose'
alias d='docker'
alias g='git'
alias nv='nvim'
alias k='kubectl'
alias ks='kubectl'
alias tf='terraform'
alias grep='grep --color=auto'
alias sudp='sudo'
alias bc='bc -q'

# Navigation & Safety
alias ..='cd ..'
alias ...='cd ../..'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -vI'

# --- GIT PROMPT ---
# Provides __git_ps1 for both prompts. Vendored from git's
# contrib/completion/git-prompt.sh.
source "$HOME/.config/shell/git-prompt.sh"

# --- CUSTOM FUNCTIONS ---
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Auto-attach tmux on SSH login
if [ -z "$TMUX" ] && [ -n "$SSH_TTY" ]; then
    tmux attach-session -t main || tmux new-session -s main
fi
