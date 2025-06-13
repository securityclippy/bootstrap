#!/bin/bash

# Linux Development Environment Bootstrap Script
# This script is idempotent - safe to run multiple times
# Usage: curl -fsSL https://raw.githubusercontent.com/securityclippy/bootstrap/main/bootstrap.sh | bash

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

# Install essential packages including asdf dependencies
install_essentials() {
    log_info "Installing essential packages and asdf dependencies..."
    
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
                software-properties-common \
                autoconf \
                bison \
                libssl-dev \
                libyaml-dev \
                libreadline6-dev \
                zlib1g-dev \
                libncurses5-dev \
                libffi-dev \
                libgdbm-dev \
                libsqlite3-dev \
                libgmp-dev \
                pkg-config
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
                gnupg2 \
                autoconf \
                bison \
                openssl-devel \
                libyaml-devel \
                readline-devel \
                zlib-devel \
                ncurses-devel \
                libffi-devel \
                gdbm-devel \
                sqlite-devel \
                gmp-devel \
                pkgconfig
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
                gnupg \
                autoconf \
                bison \
                openssl \
                libyaml \
                readline \
                zlib \
                ncurses \
                libffi \
                gdbm \
                sqlite \
                gmp \
                pkgconfig
            ;;
    esac
    
    log_success "Essential packages and asdf dependencies installed"
}

# Download configuration files
download_config_files() {
    log_info "Downloading configuration files..."
    
    local config_base_url="${CONFIG_BASE_URL:-https://raw.githubusercontent.com/securityclippy/bootstrap/main/config}"
    local config_dir="$HOME/.bootstrap-config"
    
    mkdir -p "$config_dir"
    
    # List of config files to download
    local config_files=(
        ".tool-versions"
        "brew-packages.txt"
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

# Install asdf
install_asdf() {
    brew install asdf
    
    log_success "asdf installed successfully"
}

# Install asdf plugins and tools from .tool-versions
install_asdf_tools() {
    log_info "Installing development tools via asdf..."
    
    # Source asdf
    export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
    . "$HOME/.asdf/asdf.sh"
    
    local config_file="$HOME/.bootstrap-config/.tool-versions"
    local tool_versions_file=""
    
    # Use downloaded .tool-versions or fall back to current directory or defaults
    if [[ -f "$config_file" ]]; then
        tool_versions_file="$config_file"
        log_info "Using .tool-versions from config"
    elif [[ -f ".tool-versions" ]]; then
        tool_versions_file=".tool-versions"
        log_info "Using .tool-versions from current directory"
    else
        log_warning "No .tool-versions found, creating default configuration"
        cat > "$HOME/.tool-versions" << 'EOF'
# Development runtimes
nodejs 22.11.0
python 3.13.4
ruby 3.4.4
golang 1.24.4

# DevOps tools
terraform 1.5.2
kubectl 1.30.0
helm 3.16.0

# Additional tools
direnv 2.33.0
shellcheck 0.10.0
jq 1.7.1
yq 4.44.1
EOF
        tool_versions_file="$HOME/.tool-versions"
    fi
    
    # Parse .tool-versions and install plugins
    local tools=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Extract tool name (first word)
        local tool=$(echo "$line" | awk '{print $1}')
        [[ -n "$tool" ]] && tools+=("$tool")
    done < "$tool_versions_file"
    
    # Install plugins for all tools
    for tool in "${tools[@]}"; do
        if ! asdf plugin list | grep -q "^$tool$"; then
            log_info "Adding asdf plugin: $tool"
            if asdf plugin add "$tool"; then
                log_success "Added plugin: $tool"
            else
                log_warning "Failed to add plugin: $tool (may not exist)"
            fi
        else
            log_info "Plugin $tool already installed"
        fi
    done
    
    # Install tools from .tool-versions
    if [[ -f "$tool_versions_file" ]]; then
        log_info "Installing tools from $tool_versions_file..."
        cd "$(dirname "$tool_versions_file")"
        if asdf install; then
            log_success "All tools installed successfully"
        else
            log_warning "Some tools failed to install, continuing..."
        fi
    fi
    
    log_success "asdf tools installation completed"
}

# Install Homebrew (for system tools only)
install_homebrew() {
    if command_exists brew; then
        log_info "Homebrew already installed, updating..."
        brew update
        log_success "Homebrew updated"
        return
    fi
    
    log_info "Installing Homebrew for system tools..."
    
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

# Install system tools via Homebrew (tools that don't need version management)
install_system_tools() {
    log_info "Installing system tools via Homebrew..."
    
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
        log_warning "No brew-packages.txt found, using default system tools"
        packages=(
            "gh"              # GitHub CLI
            "tree"            # Directory tree viewer
            "htop"            # Process viewer
            "bat"             # Better c
            "fd"              # Better find
            "ripgrep"         # Better grep
            "fzf"             # Fuzzy finder
            "neovim"          # Text editor
            "tmux"            # Terminal multiplexer
            "zsh"             # Shell
            "git-lfs"         # Git Large File Storage
            "lazygit"         # Git TUI
            "docker-compose"  # Container orchestration
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
    
    log_success "System tools installed"
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


# Create common development directories


# Configure shell for optimal asdf performance
configure_shell() {
    log_info "Configuring shell for optimal asdf performance..."
    
    SHELL_PROFILE=""
    if [[ -n "$ZSH_VERSION" ]]; then
        SHELL_PROFILE="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        SHELL_PROFILE="$HOME/.bashrc"
    fi
    
    if [[ -n "$SHELL_PROFILE" && -f "$SHELL_PROFILE" ]]; then
        # Add auto-install hook for .tool-versions
        if ! grep -q "auto_asdf_install" "$SHELL_PROFILE"; then
            cat >> "$SHELL_PROFILE" << 'EOF'

# Auto-install asdf tools when entering directory with .tool-versions
auto_asdf_install() {
    if [ -f ".tool-versions" ] && [ -d ".git" ]; then
        echo "🔧 Installing tools from .tool-versions..."
        asdf install
    fi
}

# Hook into directory changes
cd() {
    builtin cd "$@"
    auto_asdf_install
}
EOF
            log_info "Added auto-install hook to $SHELL_PROFILE"
        fi
    fi
    
    log_success "Shell configuration completed"
}

# Validate installation
validate_installation() {
    log_info "Validating installation..."
    
    # Source shell environment
    export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        . "$HOME/.asdf/asdf.sh"
    fi
    
    # Check asdf
    if command_exists asdf; then
        log_success "asdf: $(asdf version)"
        asdf current 2>/dev/null || true
    else
        log_warning "asdf not found in PATH"
    fi
    
    # Check Homebrew
    if command_exists brew; then
        log_success "Homebrew: $(brew --version | head -n1)"
    else
        log_warning "Homebrew not found in PATH"
    fi
    
    # Check Git
    if command_exists git; then
        log_success "Git: $(git --version)"
    else
        log_warning "Git not found"
    fi
}

# Main execution
main() {
    log_info "Starting Linux development environment bootstrap..."
    log_info "This script uses asdf for development tools and Homebrew for system utilities"
    
    check_linux_distro
    download_config_files
    update_system
    install_essentials
    install_asdf
    install_asdf_tools
    install_homebrew
    install_system_tools
    install_additional_packages
    configure_shell
    validate_installation
    
    log_success "Bootstrap completed successfully!"
    log_info ""
    log_info "🎉 Your development environment is ready!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Restart your shell or run 'source ~/.bashrc' (or ~/.zshrc)"
    log_info "2. Navigate to a project directory and run 'asdf current' to see active versions"
    log_info "3. Create a .tool-versions file in your projects for version consistency"
    log_info "4. Run this script again anytime to update your environment"
    log_info ""
    log_info "Tool versions installed:"
    
    # Show installed versions if available
    export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        . "$HOME/.asdf/asdf.sh"
        asdf current 2>/dev/null || echo "  Run 'asdf current' after restarting your shell to see versions"
    fi
}

# Run main function
main "$@"
