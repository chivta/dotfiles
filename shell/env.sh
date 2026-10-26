# Environment for macOS and Arch, sourced from bash/.bashrc. Export GOPATH
# before sourcing to override the default.

export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$HOME/.local/bin:$HOME/.local/npm/bin:$HOME/.cargo/bin:$HOME/.tfenv/bin:$GOPATH/bin:$PATH"
export PAGER='less'
export LESS='-RF --mouse'
# difft is git's diff.external, and it can spend minutes on one file (a 530KB
# generated docs.go took >60s). Past this size it uses a line-oriented diff,
# which is what stops `git diff` appearing to hang when the pager asks for more.
export DFT_BYTE_LIMIT=500000
export KUBECONFIG="$HOME/.kube/config"
