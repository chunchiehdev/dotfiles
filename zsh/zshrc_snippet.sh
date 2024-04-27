# Git
alias gs='git as'

# Docker 
alias dcp='docker compose up'
alias dcd='docker compose down'
alias dps="docker ps --format '{\"ContainerID\": \"{{.ID}}\",\"Image\": \"{{.Image}}\", \"Ports\": \"{{.Ports}}\", \"Names\": \"{{.Names}}\"}' | jq"

# History
alias his='history'

# K8S
alias kl='kubectl'
alias klgp='kubectl get pods'
