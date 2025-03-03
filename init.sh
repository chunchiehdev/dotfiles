#!/bin/bash
# curl -sL https://raw.githubusercontent.com/{github username}/dotfiles/main/init.sh | bash
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

# Clone dotfiles repository
echo -e "${YELLOW}Cloning dotfiles repository...${NC}"
if [ -d "$REPO_PATH" ]; then
    echo -e "${GREEN}Dotfiles repository already exists, updating...${NC}"
    cd "$REPO_PATH"
    git pull
else
    echo -e "${GREEN}Cloning new dotfiles repository...${NC}"
    git clone "$REPO_URL" "$REPO_PATH"
fi

# Run Ansible playbook
echo -e "${YELLOW}Running Ansible playbook...${NC}"
cd "$REPO_PATH/ansible"
ansible-playbook setup.yml -K

echo -e "${GREEN}Environment setup complete!${NC}"
echo -e "${YELLOW}Please restart your terminal to apply changes${NC}"

