#!/bin/bash
# Script to set up a development environment.
# Last modified: 2025-03-05
# curl -s https://raw.githubusercontent.com/chunchiehdev/dotfiles/main/init.sh -o init.sh
# chmod +x init.sh
# ./init.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/chunchiehdev/dotfiles.git"
REPO_PATH="$HOME/dotfiles"
OS="$(uname -s)"

debug_log() {
    echo -e "${BLUE}DEBUG: $1${NC}" >&2
}

set +e
trap 'echo -e "${RED}Error occurred at line $LINENO. Command: $BASH_COMMAND${NC}" >&2' ERR

echo -e "${GREEN}Starting setup of your development environment...${NC}"

if [ -t 0 ]; then
    INTERACTIVE=true
    debug_log "Running in interactive mode"
else
    INTERACTIVE=false
    echo -e "${RED}This script requires interactive input. Please run directly instead of through a pipe.${NC}"
    exit 1
fi

# Check operating system and install dependencies
echo -e "${YELLOW}Checking operating system...${NC}"
if [ "$OS" = "Darwin" ]; then
    echo -e "${GREEN}macOS detected${NC}"
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    echo -e "${YELLOW}Installing Git and Ansible...${NC}"
    brew install git ansible
elif [ "$OS" = "Linux" ]; then
    echo -e "${GREEN}Linux detected${NC}"
    if grep -q "microsoft" /proc/version 2>/dev/null; then
        echo -e "${GREEN}WSL environment detected${NC}"
    fi
    if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        echo -e "${YELLOW}Installing packages using apt...${NC}"
        sudo apt update
        sudo apt install -y git ansible
    elif [ -f /etc/fedora-release ]; then
        echo -e "${YELLOW}Installing packages using dnf...${NC}"
        sudo dnf install -y git ansible
    elif [ -f /etc/arch-release ]; then
        echo -e "${YELLOW}Installing packages using pacman...${NC}"
        sudo pacman -Sy git ansible --noconfirm
    else
        echo -e "${RED}Unsupported Linux distribution${NC}"
        exit 1
    fi
else
    echo -e "${RED}Unsupported operating system: $OS${NC}"
    exit 1
fi

# Function to get user confirmation
get_confirmation() {
    local prompt="$1"
    local default_value="$2"
    local valid_values="$3"
    local result=""
    
    while true; do
        read -r -p "$(echo -e "${YELLOW}$prompt${NC} ")" result
        result=$(echo "$result" | tr '[:upper:]' '[:lower:]')  # 轉換輸入為小寫
        if [[ -z "$result" ]]; then
            result="$default_value"
        fi
        if [[ " $valid_values " == *" $result "* ]]; then
            echo "$result"
            return 0
        else
            echo -e "${RED}Invalid input, please enter one of the following: $valid_values${NC}"
        fi
    done
}

run_ansible_playbook() {
    echo -e "${YELLOW}Running Ansible playbook...${NC}"
    
    if [ ! -d "$REPO_PATH/ansible" ]; then
        echo -e "${RED}Error: Ansible directory does not exist! Please make sure the repository has been successfully cloned.${NC}"
        exit 1
    fi

    cd "$REPO_PATH/ansible"
    
    # Ensure `ansible-playbook` is available
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}Error: ansible-playbook is not installed, please install Ansible manually!${NC}"
        exit 1
    fi

    echo -e "${GREEN}Ansible Playbook is starting...${NC}"
    ansible-playbook setup.yml -K
}

# Function to set up SSH key
setup_ssh_key() {
    debug_log "Entering setup_ssh_key function"
    echo -e "${YELLOW}Checking SSH key...${NC}"
    
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        echo -e "${GREEN}SSH key not found, generating...${NC}"
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
        echo -e "\n${GREEN}Please follow these steps:${NC}"
        echo -e "${GREEN}1. Copy the complete SSH public key above${NC}"
        echo -e "${GREEN}2. Visit https://github.com/settings/keys${NC}"
        echo -e "${GREEN}3. Click 'New SSH key'${NC}"
        echo -e "${GREEN}4. Enter a title (e.g., $(hostname))${NC}"
        echo -e "${GREEN}5. Paste the public key and click 'Add SSH key'${NC}"
        echo -e "${RED}=============================================${NC}\n"
        
        confirmation=""
        while [[ "$confirmation" != "yes" ]]; do
            confirmation=$(get_confirmation "After adding the key, type 'yes' and press Enter to continue:" "no" "yes")
            if [[ "$confirmation" == "yes" ]]; then
            break  # 確保一旦輸入 yes 立即結束迴圈
            fi
            echo -e "${RED}Please enter 'yes' to confirm you have added the SSH key:${NC}"
        done
        USE_SSH=true
    else
        echo -e "${GREEN}Existing SSH key found${NC}"
        eval "$(ssh-agent -s)"
        if ! ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null; then
            echo -e "${YELLOW}Please enter your SSH key passphrase${NC}"
            ssh-add "$HOME/.ssh/id_ed25519" || {
                echo -e "${RED}Could not add SSH key to agent, using HTTPS instead.${NC}"
                USE_SSH=false
            }
        fi
        
        USE_SSH=true
        echo -e "${YELLOW}Testing existing SSH connection to GitHub...${NC}"
        if ! ssh -T git@github.com -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 2>&1 | grep -q "successfully authenticated"; then
            echo -e "${RED}Warning: Existing SSH key does not work with GitHub.${NC}"
            gen_new=$(get_confirmation "Generate new key? (yes/no):" "no" "yes no")
            if [ "$gen_new" = "yes" ]; then
                timestamp=$(date +%Y%m%d%H%M%S)
                backup_dir="$HOME/.ssh/backup_$timestamp"
                mkdir -p "$backup_dir"
                cp "$HOME/.ssh/id_ed25519" "$backup_dir/"
                cp "$HOME/.ssh/id_ed25519.pub" "$backup_dir/"
                echo -e "${GREEN}Existing keys backed up to $backup_dir${NC}"
                rm -f "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub"
                setup_ssh_key
            else
                echo -e "${YELLOW}Continuing with existing key, SSH operations may fail.${NC}"
                USE_SSH=false
            fi
        else
            echo -e "${GREEN}Existing SSH key works with GitHub!${NC}"
        fi
    fi
    debug_log "Exiting setup_ssh_key function"
}

# Function to update repository URL from HTTPS to SSH
update_repo_url() {
    debug_log "Entering update_repo_url function"
    if [ -d "$REPO_PATH" ] && [ "$USE_SSH" = "true" ]; then
        cd "$REPO_PATH"
        CURRENT_URL=$(git remote get-url origin)
        if [[ $CURRENT_URL == https://github.com/* ]]; then
            SSH_URL=$(echo "$CURRENT_URL" | sed 's|https://github.com/|git@github.com:|')
            echo -e "${YELLOW}Converting repository URL from HTTPS to SSH...${NC}"
            git remote set-url origin "$SSH_URL"
            echo -e "${GREEN}Updated repository URL to: $SSH_URL${NC}"
        fi
    fi
    debug_log "Exiting update_repo_url function"
}

# Set up SSH key before cloning
setup_ssh_key

# Define SSH clone URL
REPO_URL_SSH="git@github.com:chunchiehdev/dotfiles.git"

# Clone or update repository
echo -e "${YELLOW}Cloning dotfiles repository...${NC}"
if [ -d "$REPO_PATH" ]; then
    echo -e "${GREEN}dotfiles repository already exists, updating...${NC}"
    cd "$REPO_PATH"
    git pull
else
    echo -e "${GREEN}Cloning new dotfiles repository...${NC}"
    if [ "$USE_SSH" = "true" ]; then
        echo -e "${YELLOW}Cloning using SSH URL...${NC}"
        git clone "$REPO_URL_SSH" "$REPO_PATH"
    else
        echo -e "${YELLOW}Cloning using HTTPS URL...${NC}"
        git clone "$REPO_URL" "$REPO_PATH"
    fi
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Unable to clone repository.${NC}"
        exit 1
    fi
fi

# Ensure using SSH URL if SSH is available
if [ -d "$REPO_PATH" ] && [ "$USE_SSH" = "true" ]; then
    update_repo_url
else
    echo -e "${YELLOW}Using HTTPS for repository access${NC}"
fi

if [ -d "$REPO_PATH/ansible" ]; then
    run_ansible_playbook
else
    echo -e "${RED}Error: Ansible Playbook directory does not exist! Please make sure the repository has been successfully cloned. ${NC}"
    exit 1
fi

echo -e "${GREEN}Environment setup complete!${NC}"
echo -e "${YELLOW}Please restart your terminal to apply changes${NC}"
debug_log "Script completed successfully"
