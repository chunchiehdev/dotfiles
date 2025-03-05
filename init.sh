#!/bin/bash
# Script to set up a development environment by installing dependencies, cloning a dotfiles repository, and configuring SSH.
# Last modified: 2025-03-04

debug_log() {
    echo -e "${BLUE}DEBUG: $1${NC}" >&2
}

set +e
trap 'echo -e "${RED}Error occurred at line $LINENO. Command: $BASH_COMMAND${NC}" >&2' ERR

AUTO_MODE=${AUTO_MODE:-false}

REPO_URL="https://github.com/chunchiehdev/dotfiles.git"
REPO_PATH="$HOME/dotfiles"
OS="$(uname -s)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

debug_log "Script started"

# 檢測是否在互動模式下運行
if [ -t 0 ]; then
    INTERACTIVE=true
    debug_log "Running in interactive mode"
else
    INTERACTIVE=false
    debug_log "Running in non-interactive mode"

    exec < /dev/tty 2>/dev/null
    if [ $? -eq 0 ]; then
        INTERACTIVE=true
        debug_log "Successfully reopened terminal input. Interactive mode enabled."
    else
        debug_log "Cannot reopen terminal input. Still non-interactive."
    fi
fi

if [ "$INTERACTIVE" = "false" ]; then
    echo -e "${RED}Detected non-interactive mode. Restarting as interactive bash...${NC}"
    exec bash -i "$0"
fi

# Check operating system
echo -e "${YELLOW}Checking operating system...${NC}"
if [ "$OS" = "Darwin" ]; then
    echo -e "${GREEN}Detected macOS${NC}"

    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    echo -e "${YELLOW}Installing Git and Ansible...${NC}"
    brew install git ansible
elif [ "$OS" = "Linux" ]; then
    echo -e "${GREEN}Detected Linux${NC}"
    
    if grep -q "microsoft" /proc/version 2>/dev/null; then
        echo -e "${GREEN}Detected WSL environment${NC}"
    fi
    
    if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        echo -e "${YELLOW}Using apt to install packages...${NC}"
        sudo apt update
        sudo apt install -y git ansible
    elif [ -f /etc/fedora-release ]; then
        echo -e "${YELLOW}Using dnf to install packages...${NC}"
        sudo dnf install -y git ansible
    elif [ -f /etc/arch-release ]; then
        echo -e "${YELLOW}Using pacman to install packages...${NC}"
        sudo pacman -Sy git ansible --noconfirm
    else
        echo -e "${RED}Unsupported Linux distribution${NC}"
        exit 1
    fi
else
    echo -e "${RED}Unsupported operating system: $OS${NC}"
    exit 1
fi

debug_log "OS check and package installation completed"

# Function to get user confirmation with TTY fallback
get_confirmation() {
    local prompt="$1"
    local default_value="$2"
    local valid_values="$3"
    local result=""
    
    while true; do
        echo -e "${YELLOW}$prompt${NC}"
        exec 3<&0
        exec < /dev/tty
        read -r result
        exec 0<&3
        
        if [ -z "$result" ]; then
            result="$default_value"
        fi

        if [ -z "$valid_values" ] || [[ "$valid_values" == *"$result"* ]]; then
            echo "$result"
            return 0
        else
            echo -e "${RED}Invalid input. Please enter one of: $valid_values${NC}"
        fi
    done
}

setup_ssh_key() {
    debug_log "Entering setup_ssh_key function"
    echo -e "${YELLOW}Checking SSH key...${NC}"
    
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        echo -e "${GREEN}No SSH key found, generating one...${NC}"
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$HOME/.ssh/id_ed25519" -N ""
        chmod 600 "$HOME/.ssh/id_ed25519"
        chmod 644 "$HOME/.ssh/id_ed25519.pub"
        eval "$(ssh-agent -s)"
        ssh-add "$HOME/.ssh/id_ed25519"
        
        echo -e "\n${RED}================== ACTION REQUIRED ==================${NC}"
        echo -e "${RED}Please add the following SSH public key to your GitHub account:${NC}"
        echo -e "${YELLOW}$(cat "$HOME/.ssh/id_ed25519.pub")${NC}"
        echo -e "${RED}=====================================================${NC}\n"
        
        confirmation=""
        while [ "$confirmation" != "yes" ]; do
            confirmation=$(get_confirmation "After adding the key, type 'yes' and press Enter to continue:" "no" "yes")
            if [ "$confirmation" != "yes" ]; then
                echo -e "${RED}Please type 'yes' to confirm you've added the SSH key.${NC}"
            fi
        done
        echo -e "${GREEN}SSH key setup completed.${NC}"
    else
        echo -e "${GREEN}Existing SSH key found.${NC}"
    fi
}

setup_ssh_key

echo -e "${GREEN}Setup complete.${NC}"
