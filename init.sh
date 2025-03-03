#!/bin/bash
# Script to set up a development environment by installing dependencies, cloning a dotfiles repository, and configuring SSH.

set -e

REPO_URL="https://github.com/chunchiehdev/dotfiles.git"
REPO_PATH="$HOME/dotfiles"
OS="$(uname -s)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}Starting to set up your development environment...${NC}"

# Check operating system
echo -e "${YELLOW}Checking operating system...${NC}"
if [ "$OS" = "Darwin" ]; then
    echo -e "${GREEN}Detected macOS${NC}"

    # Check and install Homebrew
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Install Git and Ansible using Homebrew
    echo -e "${YELLOW}Installing Git and Ansible...${NC}"
    brew install git ansible
elif [ "$OS" = "Linux" ]; then
    echo -e "${GREEN}Detected Linux${NC}"
    
    # Check distribution
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

# Function to set up SSH key
setup_ssh_key() {
    echo -e "${YELLOW}Checking SSH key...${NC}"
    
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        echo -e "${GREEN}No SSH key found, generating one...${NC}"
        
        # Generate SSH key pair
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$HOME/.ssh/id_ed25519" -N ""
        
        # Start ssh-agent
        eval "$(ssh-agent -s)"
        ssh-add "$HOME/.ssh/id_ed25519"
        
        # Display public key and provide instructions
        echo -e "${RED}Please add the following SSH public key to your GitHub account:${NC}"
        cat "$HOME/.ssh/id_ed25519.pub"
        echo -e "${YELLOW}Visit https://github.com/settings/keys to add the key above.${NC}"
        
        # Wait for user confirmation
        read -p "Press Enter to continue setup, or Ctrl+C to cancel..."
    else
        echo -e "${GREEN}Existing SSH key found${NC}"
        # Ensure ssh-agent is running
        eval "$(ssh-agent -s)"
        ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || echo -e "${YELLOW}Please enter your SSH key passphrase${NC}"
    fi
}

# Function to update repository URL from HTTPS to SSH
update_repo_url() {
    if [ -d "$REPO_PATH" ]; then
        cd "$REPO_PATH"
        CURRENT_URL=$(git remote get-url origin)
        
        # If the URL is in HTTPS format, convert it to SSH
        if [[ $CURRENT_URL == https://github.com/* ]]; then
            # Convert URL: https://github.com/user/repo.git -> git@github.com:user/repo.git
            SSH_URL=$(echo "$CURRENT_URL" | sed 's|https://github.com/|git@github.com:|')
            
            echo -e "${YELLOW}Converting repository URL from HTTPS to SSH...${NC}"
            git remote set-url origin "$SSH_URL"
            echo -e "${GREEN}Updated repository URL to: $SSH_URL${NC}"
        fi
    fi
}

# Set up SSH key before cloning
setup_ssh_key

# Define SSH URL for cloning (replace 'chunchiehdev' with your GitHub username if different)
REPO_URL_SSH="git@github.com:chunchiehdev/dotfiles.git"

# Clone or update dotfiles repository
echo -e "${YELLOW}Cloning dotfiles repository...${NC}"
if [ -d "$REPO_PATH" ]; then
    echo -e "${GREEN}Dotfiles repository already exists, updating...${NC}"
    cd "$REPO_PATH"
    git pull
else
    echo -e "${GREEN}Cloning new dotfiles repository...${NC}"
    # Attempt cloning with SSH URL, fallback to HTTPS if SSH fails
    git clone "$REPO_URL_SSH" "$REPO_PATH" || git clone "$REPO_URL" "$REPO_PATH"
fi

# Ensure repository uses SSH URL
update_repo_url

# Run Ansible playbook (uncomment and adjust path as needed)
echo -e "${YELLOW}Running Ansible playbook...${NC}"
# cd "$REPO_PATH/ansible"
# ansible-playbook setup.yml -K

echo -e "${GREEN}Environment setup complete!${NC}"
echo -e "${YELLOW}Please restart your terminal to apply changes${NC}"
