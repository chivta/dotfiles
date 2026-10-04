# Environment shared by zsh (macOS, sourced from .zprofile) and bash (Arch,
# sourced from .bashrc). Export GOPATH before sourcing to override the default.

export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$HOME/.local/bin:$HOME/.local/npm/bin:$HOME/.cargo/bin:$HOME/.tfenv/bin:$GOPATH/bin:$PATH"
export PAGER='less'
export LESS='-RFX --mouse'
export KUBECONFIG="$HOME/.kube/config"
