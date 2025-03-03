#!/bin/bash
# Script to set up a development environment by installing dependencies, cloning a dotfiles repository, and configuring SSH.
# Last modified: 2025-03-03 by chunchiehdev

set -e

REPO_URL="https://github.com/chunchiehdev/dotfiles.git"
REPO_PATH="$HOME/dotfiles"
OS="$(uname -s)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -t 0 ]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
    echo -e "${YELLOW}======================= WARNING =======================${NC}"
    echo -e "${YELLOW}This script contains interactive steps.${NC}"
    echo -e "${YELLOW}For best experience, please download and run directly:${NC}"
    echo -e "${BLUE}  curl -s https://raw.githubusercontent.com/chunchiehdev/dotfiles/main/init.sh -o init.sh${NC}"
    echo -e "${BLUE}  chmod +x init.sh${NC}"
    echo -e "${BLUE}  ./init.sh${NC}"
    echo -e "${YELLOW}=====================================================${NC}"
    echo ""
    echo -e "${GREEN}Continuing in 5 seconds... Press Ctrl+C to cancel${NC}"
    sleep 5
fi

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
    
    # Check for WSL
    if grep -q "microsoft" /proc/version 2>/dev/null; then
        echo -e "${GREEN}Detected WSL environment${NC}"
    fi
    
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
        
        # Ensure .ssh directory exists with correct permissions
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        
        # Generate SSH key pair
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$HOME/.ssh/id_ed25519" -N ""
        
        # Set correct permissions
        chmod 600 "$HOME/.ssh/id_ed25519"
        chmod 644 "$HOME/.ssh/id_ed25519.pub"
        
        # Start ssh-agent
        eval "$(ssh-agent -s)"
        ssh-add "$HOME/.ssh/id_ed25519"
        
        # Display public key and provide clear instructions
        echo -e "\n${RED}================== ACTION REQUIRED ==================${NC}"
        echo -e "${RED}Please add the following SSH public key to your GitHub account:${NC}"
        echo -e "${YELLOW}$(cat "$HOME/.ssh/id_ed25519.pub")${NC}"
        echo -e "\n${GREEN}Follow these steps:${NC}"
        echo -e "${GREEN}1. Copy the entire SSH key above${NC}"
        echo -e "${GREEN}2. Visit https://github.com/settings/keys${NC}"
        echo -e "${GREEN}3. Click 'New SSH key'${NC}"
        echo -e "${GREEN}4. Enter a title (e.g., $(hostname))${NC}"
        echo -e "${GREEN}5. Paste the key and click 'Add SSH key'${NC}"
        echo -e "${RED}=====================================================${NC}\n"
        
        # Use /dev/tty to read from terminal even in pipeline
        echo -e "${YELLOW}After adding the key, type 'yes' and press Enter to continue:${NC}"
        confirmation=""
        while [ "$confirmation" != "yes" ]; do
            if ! read -r confirmation </dev/tty; then
                echo -e "${RED}ERROR: Cannot read from terminal. This script must be run interactively.${NC}"
                echo -e "${RED}Please download the script first and run it directly:${NC}"
                echo -e "${BLUE}  curl -s https://raw.githubusercontent.com/chunchiehdev/dotfiles/main/init.sh -o init.sh${NC}"
                echo -e "${BLUE}  chmod +x init.sh${NC}"
                echo -e "${BLUE}  ./init.sh${NC}"
                exit 1
            fi
            
            if [ "$confirmation" != "yes" ]; then
                echo -e "${RED}Please type 'yes' to confirm you've added the SSH key:${NC}"
            fi
        done
        
        # Test SSH connection
        echo -e "${YELLOW}Testing SSH connection to GitHub...${NC}"
        if ! ssh -T git@github.com -o StrictHostKeyChecking=accept-new -o BatchMode=yes 2>&1 | grep -q "successfully authenticated"; then
            echo -e "${RED}SSH connection test failed. This could be due to:${NC}"
            echo -e "${YELLOW}1. The SSH key hasn't been added to your GitHub account yet${NC}"
            echo -e "${YELLOW}2. The key hasn't propagated through GitHub's system yet${NC}"
            echo -e "${YELLOW}3. Network/firewall issues${NC}"
            
            echo -e "${YELLOW}Would you like to try again? (yes/no):${NC}"
            retry=""
            read -r retry </dev/tty || retry="no"
            
            if [ "$retry" = "yes" ]; then
                echo -e "${YELLOW}Testing SSH connection again...${NC}"
                if ! ssh -T git@github.com -o StrictHostKeyChecking=accept-new 2>&1 | grep -q "successfully authenticated"; then
                    echo -e "${RED}SSH connection test failed again.${NC}"
                    echo -e "${YELLOW}Do you want to continue anyway? This might cause issues with Git operations.${NC}"
                    echo -e "${YELLOW}Type 'continue' to proceed or anything else to exit:${NC}"
                    
                    proceed=""
                    read -r proceed </dev/tty || proceed=""
                    
                    if [ "$proceed" != "continue" ]; then
                        echo -e "${RED}Setup cancelled.${NC}"
                        exit 1
                    fi
                else
                    echo -e "${GREEN}SSH connection successful!${NC}"
                fi
            else
                echo -e "${RED}SSH connection test skipped.${NC}"
                echo -e "${YELLOW}Type 'continue' to proceed or anything else to exit:${NC}"
                
                proceed=""
                read -r proceed </dev/tty || proceed=""
                
                if [ "$proceed" != "continue" ]; then
                    echo -e "${RED}Setup cancelled.${NC}"
                    exit 1
                fi
            fi
        else
            echo -e "${GREEN}SSH connection successful!${NC}"
        fi
    else
        echo -e "${GREEN}Existing SSH key found${NC}"
        # Ensure ssh-agent is running
        eval "$(ssh-agent -s)"
        ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || {
            echo -e "${YELLOW}Please enter your SSH key passphrase${NC}"
            ssh-add "$HOME/.ssh/id_ed25519"
        }
        
        # Test existing key
        echo -e "${YELLOW}Testing existing SSH connection to GitHub...${NC}"
        if ! ssh -T git@github.com -o BatchMode=yes -o StrictHostKeyChecking=accept-new 2>&1 | grep -q "successfully authenticated"; then
            echo -e "${RED}Warning: Your existing SSH key doesn't work with GitHub.${NC}"
            echo -e "${YELLOW}Would you like to generate a new key? (yes/no):${NC}"
            
            gen_new=""
            read -r gen_new </dev/tty || gen_new="no"
            
            if [ "$gen_new" = "yes" ]; then
                timestamp=$(date +%Y%m%d%H%M%S)
                backup_dir="$HOME/.ssh/backup_$timestamp"
                mkdir -p "$backup_dir"
                cp "$HOME/.ssh/id_ed25519" "$backup_dir/"
                cp "$HOME/.ssh/id_ed25519.pub" "$backup_dir/"
                
                echo -e "${GREEN}Backed up existing keys to $backup_dir${NC}"
                rm -f "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub"
                
                # Recursive call to generate new key
                setup_ssh_key
            else
                echo -e "${YELLOW}Continuing with existing key. SSH operations may fail.${NC}"
                echo -e "${YELLOW}Type 'continue' to proceed:${NC}"
                
                proceed=""
                read -r proceed </dev/tty || proceed=""
                
                if [ "$proceed" != "continue" ]; then
                    echo -e "${RED}Setup cancelled.${NC}"
                    exit 1
                fi
            fi
        else
            echo -e "${GREEN}Existing SSH key works with GitHub!${NC}"
        fi
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

# Define SSH URL for cloning
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
    if ! git clone "$REPO_URL_SSH" "$REPO_PATH"; then
        echo -e "${YELLOW}SSH cloning failed, falling back to HTTPS...${NC}"
        git clone "$REPO_URL" "$REPO_PATH"
    fi
fi

# Ensure repository uses SSH URL
update_repo_url

# Run Ansible playbook (uncomment and adjust path as needed)
echo -e "${YELLOW}Running Ansible playbook...${NC}"
# cd "$REPO_PATH/ansible"
# ansible-playbook setup.yml -K

echo -e "${GREEN}Environment setup complete!${NC}"
echo -e "${YELLOW}Please restart your terminal to apply changes${NC}"
