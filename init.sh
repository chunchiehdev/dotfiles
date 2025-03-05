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
    
    if [ "$AUTO_MODE" = "true" ]; then
        echo -e "${YELLOW}Running in automatic mode with default options${NC}"
    else
        echo -e "${YELLOW}======================= WARNING =======================${NC}"
        echo -e "${YELLOW}This script contains interactive steps.${NC}"
        echo -e "${YELLOW}For best experience, please either:${NC}"
        echo -e "${BLUE}  1. Download and run directly:${NC}"
        echo -e "${BLUE}    curl -s https://raw.githubusercontent.com/chunchiehdev/dotfiles/main/init.sh -o init.sh${NC}"
        echo -e "${BLUE}    chmod +x init.sh${NC}"
        echo -e "${BLUE}    ./init.sh${NC}"
        echo -e "${BLUE}  2. Run with AUTO_MODE=true:${NC}"
        echo -e "${BLUE}    curl -s https://raw.githubusercontent.com/chunchiehdev/dotfiles/main/init.sh | AUTO_MODE=true bash${NC}"
        echo -e "${YELLOW}=====================================================${NC}"
        echo ""
        echo -e "${GREEN}Continuing in 5 seconds... Press Ctrl+C to cancel${NC}"
        sleep 5
    fi
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

debug_log "OS check and package installation completed"

# Function to get user confirmation with auto-mode support
get_confirmation() {
    local prompt="$1"
    local default_value="$2"
    local valid_values="$3"
    local result=""
    
    if [ "$INTERACTIVE" = "false" ]; then
        if [ "$AUTO_MODE" = "true" ]; then
            echo -e "${YELLOW}Automatic mode: Using default value '$default_value' for '$prompt'${NC}"
            echo "$default_value"
            return 0
        else
            echo -e "${RED}ERROR: This script requires interactive input but is running in non-interactive mode.${NC}"
            echo -e "${RED}Please download the script and run it directly, or use AUTO_MODE=true:${NC}"
            echo -e "${BLUE}  curl -s https://raw.githubusercontent.com/chunchiehdev/dotfiles/main/init.sh -o init.sh${NC}"
            echo -e "${BLUE}  chmod +x init.sh${NC}"
            echo -e "${BLUE}  ./init.sh${NC}"
            echo -e "${BLUE}  # OR ${NC}"
            echo -e "${BLUE}  curl -s https://raw.githubusercontent.com/chunchiehdev/dotfiles/main/init.sh | AUTO_MODE=true bash${NC}"
            exit 1
        fi
    fi
    
    while true; do
        echo -e "${YELLOW}$prompt${NC}"
        read -r result
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

# Function to set up SSH key
setup_ssh_key() {
    debug_log "Entering setup_ssh_key function"
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
        
        # Get confirmation using our helper function
        if [ "$AUTO_MODE" = "true" ]; then
            echo -e "${YELLOW}Running in automatic mode. Assuming SSH key will be added later.${NC}"
            confirmation="yes"
        else
            confirmation=""
            while [ "$confirmation" != "yes" ]; do
                confirmation=$(get_confirmation "After adding the key, type 'yes' and press Enter to continue:" "no" "yes")
                if [ "$confirmation" != "yes" ]; then
                    echo -e "${RED}Please type 'yes' to confirm you've added the SSH key:${NC}"
                fi
            done
        fi
        
        # Test SSH connection
        USE_SSH=true
        echo -e "${YELLOW}Testing SSH connection to GitHub...${NC}"
        if ! ssh -T git@github.com -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=10 2>&1 | grep -q "successfully authenticated"; then
            echo -e "${RED}SSH connection test failed. This could be due to:${NC}"
            echo -e "${YELLOW}1. The SSH key hasn't been added to your GitHub account yet${NC}"
            echo -e "${YELLOW}2. The key hasn't propagated through GitHub's system yet${NC}"
            echo -e "${YELLOW}3. Network/firewall issues${NC}"
            
            if [ "$AUTO_MODE" = "true" ]; then
                echo -e "${YELLOW}Automatic mode: Will use HTTPS instead of SSH for repository access${NC}"
                USE_SSH=false
            else
                retry=$(get_confirmation "Would you like to try again? (yes/no):" "no" "yes no")
                
                if [ "$retry" = "yes" ]; then
                    echo -e "${YELLOW}Testing SSH connection again...${NC}"
                    if ! ssh -T git@github.com -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 2>&1 | grep -q "successfully authenticated"; then
                        echo -e "${RED}SSH connection test failed again.${NC}"
                        proceed=$(get_confirmation "Do you want to continue anyway? This might cause issues with Git operations. Type 'continue' to proceed or anything else to exit:" "exit" "continue exit")
                        
                        if [ "$proceed" != "continue" ]; then
                            echo -e "${RED}Setup cancelled.${NC}"
                            exit 1
                        fi
                        USE_SSH=false
                    else
                        echo -e "${GREEN}SSH connection successful!${NC}"
                    fi
                else
                    echo -e "${RED}SSH connection test skipped.${NC}"
                    proceed=$(get_confirmation "Type 'continue' to proceed or anything else to exit:" "exit" "continue exit")
                    
                    if [ "$proceed" != "continue" ]; then
                        echo -e "${RED}Setup cancelled.${NC}"
                        exit 1
                    fi
                    USE_SSH=false
                fi
            fi
        else
            echo -e "${GREEN}SSH connection successful!${NC}"
        fi
    else
        echo -e "${GREEN}Existing SSH key found${NC}"
        # Ensure ssh-agent is running
        eval "$(ssh-agent -s)"
        
        # Try to add key without passphrase first
        if ! ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null; then
            if [ "$AUTO_MODE" = "true" ]; then
                echo -e "${YELLOW}Automatic mode: SSH key requires passphrase. Will use HTTPS instead.${NC}"
                USE_SSH=false
            else
                echo -e "${YELLOW}Please enter your SSH key passphrase${NC}"
                ssh-add "$HOME/.ssh/id_ed25519" || {
                    echo -e "${RED}Failed to add SSH key to agent. Using HTTPS instead.${NC}"
                    USE_SSH=false
                }
            fi
        fi
        
        # Test existing key
        USE_SSH=true
        echo -e "${YELLOW}Testing existing SSH connection to GitHub...${NC}"
        if ! ssh -T git@github.com -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 2>&1 | grep -q "successfully authenticated"; then
            echo -e "${RED}Warning: Your existing SSH key doesn't work with GitHub.${NC}"
            
            if [ "$AUTO_MODE" = "true" ]; then
                echo -e "${YELLOW}Automatic mode: Using HTTPS instead of SSH${NC}"
                USE_SSH=false
            else
                gen_new=$(get_confirmation "Would you like to generate a new key? (yes/no):" "no" "yes no")
                
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
                    proceed=$(get_confirmation "Type 'continue' to proceed:" "continue" "continue")
                    
                    if [ "$proceed" != "continue" ]; then
                        echo -e "${RED}Setup cancelled.${NC}"
                        exit 1
                    fi
                    USE_SSH=false
                fi
            fi
        else
            echo -e "${GREEN}Existing SSH key works with GitHub!${NC}"
        fi
    fi
    
    debug_log "Exiting setup_ssh_key function"
    
    return 0
}

# Function to update repository URL from HTTPS to SSH
update_repo_url() {
    debug_log "Entering update_repo_url function"
    if [ -d "$REPO_PATH" ] && [ "$USE_SSH" = "true" ]; then
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
    debug_log "Exiting update_repo_url function"
}

debug_log "About to set up SSH key"
# Set up SSH key before cloning
setup_ssh_key
debug_log "SSH key setup completed"

# Define URLs for cloning
REPO_URL_SSH="git@github.com:chunchiehdev/dotfiles.git"

debug_log "About to clone repository"
# Clone or update dotfiles repository
echo -e "${YELLOW}Cloning dotfiles repository...${NC}"
if [ -d "$REPO_PATH" ]; then
    echo -e "${GREEN}Dotfiles repository already exists, updating...${NC}"
    cd "$REPO_PATH"
    git pull
    git_result=$?
    debug_log "git pull result: $git_result"
else
    echo -e "${GREEN}Cloning new dotfiles repository...${NC}"
    
    # Choose which URL to use based on SSH test result
    if [ "$USE_SSH" = "true" ]; then
        echo -e "${YELLOW}Using SSH URL for cloning...${NC}"
        git clone "$REPO_URL_SSH" "$REPO_PATH"
        git_result=$?
        debug_log "git clone with SSH result: $git_result"
    else
        echo -e "${YELLOW}Using HTTPS URL for cloning...${NC}"
        git clone "$REPO_URL" "$REPO_PATH"
        git_result=$?
        debug_log "git clone with HTTPS result: $git_result"
    fi
    
    # If primary method failed, try the alternative
    if [ $git_result -ne 0 ]; then
        if [ "$USE_SSH" = "true" ]; then
            echo -e "${YELLOW}SSH cloning failed, falling back to HTTPS...${NC}"
            git clone "$REPO_URL" "$REPO_PATH"
            git_result=$?
            debug_log "git clone with HTTPS result: $git_result"
        else
            echo -e "${YELLOW}HTTPS cloning failed, trying SSH...${NC}"
            git clone "$REPO_URL_SSH" "$REPO_PATH"
            git_result=$?
            debug_log "git clone with SSH result: $git_result"
        fi
        
        if [ $git_result -ne 0 ]; then
            echo -e "${RED}Error: Failed to clone repository.${NC}"
        fi
    fi
fi

debug_log "Repository clone/update phase completed"

# Ensure repository uses SSH URL if SSH is working
if [ -d "$REPO_PATH" ] && [ "$USE_SSH" = "true" ]; then
    debug_log "About to update repository URL"
    update_repo_url
    debug_log "Repository URL update completed"
else
    echo -e "${YELLOW}Using HTTPS for repository access${NC}"
    debug_log "Repository URL update skipped - using HTTPS"
fi

debug_log "About to run Ansible playbook phase"
# Run Ansible playbook (uncomment and adjust path as needed)
echo -e "${YELLOW}Running Ansible playbook...${NC}"
# cd "$REPO_PATH/ansible"
# ansible-playbook setup.yml -K

echo -e "${GREEN}Environment setup complete!${NC}"
echo -e "${YELLOW}Please restart your terminal to apply changes${NC}"
debug_log "Script completed successfully"
