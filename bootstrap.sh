#!/bin/bash

# Linux Development Environment Bootstrap Script
# This script is idempotent - safe to run multiple times
# Usage: curl -fsSL https://raw.githubusercontent.com/yourusername/yourrepo/main/bootstrap.sh | bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if we're on a supported Linux distribution
check_linux_distro() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script is designed for Linux systems only"
        exit 1
    fi
    
    # Detect distribution
    if command_exists apt-get; then
        DISTRO="debian"
        PKG_MANAGER="apt-get"
    elif command_exists yum; then
        DISTRO="rhel"
        PKG_MANAGER="yum"
    elif command_exists dnf; then
        DISTRO="rhel"
        PKG_MANAGER="dnf"
    elif command_exists pacman; then
        DISTRO="arch"
        PKG_MANAGER="pacman"
    else
        log_error "Unsupported Linux distribution"
        exit 1
    fi
    
    log_info "Detected Linux distribution: $DISTRO"
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    
    case $PKG_MANAGER in
        apt-get)
            sudo apt-get update -y
            ;;
        yum|dnf)
            sudo $PKG_MANAGER update -y
            ;;
        pacman)
            sudo pacman -Sy
            ;;
    esac
    
    log_success "System packages updated"
}

# Install essential packages
install_essentials() {
    log_info "Installing essential packages..."
    
    case $PKG_MANAGER in
        apt-get)
            sudo apt-get install -y \
                curl \
                wget \
                git \
                build-essential \
                file \
                procps \
                ca-certificates \
                gnupg \
                lsb-release \
                software-properties-common
            ;;
        yum|dnf)
            sudo $PKG_MANAGER install -y \
                curl \
                wget \
                git \
                gcc \
                gcc-c++ \
                make \
                file \
                procps-ng \
                ca-certificates \
                gnupg2
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm \
                curl \
                wget \
                git \
                base-devel \
                file \
                procps-ng \
                ca-certificates \
                gnupg
            ;;
    esac
    
    log_success "Essential packages installed"
}

# Install Homebrew
install_homebrew() {
    if command_exists brew; then
        log_info "Homebrew already installed, updating..."
        brew update
        log_success "Homebrew updated"
        return
    fi
    
    log_info "Installing Homebrew..."
    
    # Install Homebrew
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for current session
    if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    
    # Add to shell profile
    SHELL_PROFILE=""
    if [[ -n "$ZSH_VERSION" ]]; then
        SHELL_PROFILE="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        SHELL_PROFILE="$HOME/.bashrc"
    fi
    
    if [[ -n "$SHELL_PROFILE" && -f "$SHELL_PROFILE" ]]; then
        if ! grep -q "linuxbrew" "$SHELL_PROFILE"; then
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$SHELL_PROFILE"
            log_info "Added Homebrew to $SHELL_PROFILE"
        fi
    fi
    
    log_success "Homebrew installed successfully"
}

# Install asdf
install_asdf() {
    if [[ -d "$HOME/.asdf" ]]; then
        log_info "asdf already installed, updating..."
        cd "$HOME/.asdf"
        git pull origin master
        log_success "asdf updated"
        return
    fi
    
    log_info "Installing asdf..."
    
    # Clone asdf repository
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
    
    # Add to shell profile
    SHELL_PROFILE=""
    if [[ -n "$ZSH_VERSION" ]]; then
        SHELL_PROFILE="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        SHELL_PROFILE="$HOME/.bashrc"
    fi
    
    if [[ -n "$SHELL_PROFILE" && -f "$SHELL_PROFILE" ]]; then
        if ! grep -q "asdf.sh" "$SHELL_PROFILE"; then
            echo '. "$HOME/.asdf/asdf.sh"' >> "$SHELL_PROFILE"
            echo '. "$HOME/.asdf/completions/asdf.bash"' >> "$SHELL_PROFILE"
            log_info "Added asdf to $SHELL_PROFILE"
        fi
    fi
    
    # Source asdf for current session
    . "$HOME/.asdf/asdf.sh"
    
    log_success "asdf installed successfully"
}

# Download configuration files
download_config_files() {
    log_info "Downloading configuration files..."
    
    local config_base_url="${CONFIG_BASE_URL:-https://raw.githubusercontent.com/yourusername/yourrepo/main/config}"
    local config_dir="$HOME/.bootstrap-config"
    
    mkdir -p "$config_dir"
    
    # List of config files to download
    local config_files=(
        "brew-packages.txt"
        "asdf-languages.txt"
        "additional-packages.txt"
    )
    
    for config_file in "${config_files[@]}"; do
        local url="$config_base_url/$config_file"
        local local_path="$config_dir/$config_file"
        
        log_info "Downloading $config_file..."
        if curl -fsSL "$url" -o "$local_path"; then
            log_success "Downloaded $config_file"
        else
            log_warning "Failed to download $config_file, will use defaults if available"
        fi
    done
}

# Install packages from brew-packages.txt
install_dev_tools() {
    log_info "Installing development tools via Homebrew..."
    
    # Ensure Homebrew is in PATH
    if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    
    if ! command_exists brew; then
        log_error "Homebrew not found in PATH"
        return 1
    fi
    
    local config_file="$HOME/.bootstrap-config/brew-packages.txt"
    local packages=()
    
    # Read packages from file or use defaults
    if [[ -f "$config_file" ]]; then
        log_info "Reading Homebrew packages from $config_file"
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            packages+=("$line")
        done < "$config_file"
    else
        log_warning "No brew-packages.txt found, using default packages"
        packages=(
            "gh"              # GitHub CLI
            "jq"              # JSON processor
            "tree"            # Directory tree viewer
            "htop"            # Process viewer
            "bat"             # Better cat
            "exa"             # Better ls
            "fd"              # Better find
            "ripgrep"         # Better grep
            "fzf"             # Fuzzy finder
            "neovim"          # Text editor
            "tmux"            # Terminal multiplexer
            "zsh"             # Shell
        )
    fi
    
    for package in "${packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            log_info "$package already installed"
        else
            log_info "Installing $package..."
            brew install "$package"
        fi
    done
    
    log_success "Development tools installed"
}

# Install languages from asdf-languages.txt
install_languages() {
    log_info "Installing programming languages via asdf..."
    
    # Source asdf
    . "$HOME/.asdf/asdf.sh"
    
    local config_file="$HOME/.bootstrap-config/asdf-languages.txt"
    declare -A languages
    
    # Read languages from file or use defaults
    if [[ -f "$config_file" ]]; then
        log_info "Reading asdf languages from $config_file"
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # Parse language:version format
            if [[ "$line" =~ ^([^:]+):(.+)$ ]]; then
                local lang="${BASH_REMATCH[1]}"
                local version="${BASH_REMATCH[2]}"
                languages["$lang"]="$version"
            fi
        done < "$config_file"
    else
        log_warning "No asdf-languages.txt found, using default languages"
        languages=(
            ["nodejs"]="20.11.0"
            ["python"]="3.12.1"
            ["ruby"]="3.3.0"
            ["golang"]="1.21.6"
            ["rust"]="1.75.0"
        )
    fi
    
    for lang in "${!languages[@]}"; do
        version="${languages[$lang]}"
        
        # Add plugin if not exists
        if ! asdf plugin list | grep -q "^$lang$"; then
            log_info "Adding asdf plugin: $lang"
            asdf plugin add "$lang"
        fi
        
        # Install language version if not exists
        if ! asdf list "$lang" 2>/dev/null | grep -q "$version"; then
            log_info "Installing $lang $version..."
            asdf install "$lang" "$version"
            asdf global "$lang" "$version"
        else
            log_info "$lang $version already installed"
        fi
    done
    
    log_success "Programming languages installed"
}

# Install additional system packages from additional-packages.txt
install_additional_packages() {
    log_info "Installing additional system packages..."
    
    local config_file="$HOME/.bootstrap-config/additional-packages.txt"
    
    if [[ ! -f "$config_file" ]]; then
        log_info "No additional-packages.txt found, skipping additional packages"
        return
    fi
    
    local packages=()
    
    log_info "Reading additional packages from $config_file"
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        packages+=("$line")
    done < "$config_file"
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_info "No additional packages to install"
        return
    fi
    
    case $PKG_MANAGER in
        apt-get)
            sudo apt-get install -y "${packages[@]}"
            ;;
        yum|dnf)
            sudo $PKG_MANAGER install -y "${packages[@]}"
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm "${packages[@]}"
            ;;
    esac
    
    log_success "Additional system packages installed"
}

# Configure Git (if not already configured)
configure_git() {
    if [[ -n "$(git config --global user.name)" && -n "$(git config --global user.email)" ]]; then
        log_info "Git already configured"
        return
    fi
    
    log_info "Git configuration needed"
    echo "Please enter your Git configuration:"
    read -p "Git username: " git_username
    read -p "Git email: " git_email
    
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    
    log_success "Git configured"
}

# Create common development directories
create_dev_directories() {
    log_info "Creating development directories..."
    
    DIRECTORIES=(
        "$HOME/dev"
        "$HOME/dev/projects"
        "$HOME/dev/sandbox"
        "$HOME/.config"
    )
    
    for dir in "${DIRECTORIES[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        fi
    done
    
    log_success "Development directories created"
}

# Main execution
main() {
    log_info "Starting Linux development environment bootstrap..."
    log_info "This script is idempotent and safe to run multiple times"
    
    check_linux_distro
    download_config_files
    update_system
    install_essentials
    install_homebrew
    install_asdf
    install_dev_tools
    install_languages
    install_additional_packages
    configure_git
    create_dev_directories
    
    log_success "Bootstrap completed successfully!"
    log_info "Please restart your shell or run 'source ~/.bashrc' (or ~/.zshrc) to use the new tools"
    log_info "You can also run this script again anytime to update your environment"
    
    # Show installed versions
    echo
    log_info "Installed versions:"
    echo "  Homebrew: $(brew --version | head -n1)"
    echo "  asdf: $(asdf version)"
    echo "  Git: $(git --version)"
    
    if command_exists node; then
        echo "  Node.js: $(node --version)"
    fi
    
    if command_exists python3; then
        echo "  Python: $(python3 --version)"
    fi
}

# Run main function
main "$@"
