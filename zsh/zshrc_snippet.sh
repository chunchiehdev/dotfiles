# Vim to nvim
alias vim=nvim

# Windows
alias pbcopy='clip.exe'
alias pbpaste='powershell.exe -noprofile Get-Clipboard'

# Git
alias gs='git as'

# Docker 
alias dcp='docker compose up'
alias dcd='docker compose down'
alias dps="docker ps --format '{\"ContainerID\": \"{{.ID}}\",\"Image\": \"{{.Image}}\", \"Ports\": \"{{.Ports}}\", \"Names\": \"{{.Names}}\"}' | jq"
alias dpsa="docker ps -a --format '{\"ContainerID\": \"{{.ID}}\",\"Image\": \"{{.Image}}\", \"Ports\": \"{{.Ports}}\", \"Names\": \"{{.Names}}\"}' | jq"

# History
alias his='history'

# K8S
alias ka='kubectl apply -f'
alias kl='kubectl'
alias klgp='kubectl get pods'
alias klgd='kubectl get deploy'
alias klgs='kubectl get svc'

# Poetry shell exist enviroment
alias act="source \"\$(poetry env list --full-path | grep Activated | cut -d' ' -f1 )/bin/activate\""

export NODE_EXTRA_CA_CERTS="/usr/local/share/ca-certificates/ca.crt"
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
export NODE_OPTIONS=--openssl-legacy-provider