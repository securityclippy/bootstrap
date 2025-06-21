#!/bin/bash

# Linux Development Environment Bootstrap Script
# This script is idempotent - safe to run multiple times
# Usage: curl -fsSL https://raw.githubusercontent.com/securityclippy/bootstrap/main/bootstrap.sh | bash

# Note: Removed 'set -e' to allow script to continue on individual tool failures

# Arrays to track installation results
SUCCEEDED_STEPS=()
FAILED_STEPS=()

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

# Function to record successful step
record_success() {
    SUCCEEDED_STEPS+=("$1")
    log_success "$1"
}

# Function to record failed step
record_failure() {
    FAILED_STEPS+=("$1")
    log_error "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if we're on a supported Linux distribution
check_linux_distro() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        record_failure "This script is designed for Linux systems only"
        return 1
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
        record_failure "Unsupported Linux distribution"
        return 1
    fi
    
    record_success "Detected Linux distribution: $DISTRO"
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    
    case $PKG_MANAGER in
        apt-get)
            if sudo apt-get update -y; then
                record_success "System packages updated"
            else
                record_failure "Failed to update system packages"
                return 1
            fi
            ;;
        yum|dnf)
            if sudo $PKG_MANAGER update -y; then
                record_success "System packages updated"
            else
                record_failure "Failed to update system packages"
                return 1
            fi
            ;;
        pacman)
            if sudo pacman -Sy; then
                record_success "System packages updated"
            else
                record_failure "Failed to update system packages"
                return 1
            fi
            ;;
    esac
}

# Install essential packages including asdf dependencies and zsh
install_essentials() {
    log_info "Installing essential packages, asdf dependencies, and zsh..."
    
    case $PKG_MANAGER in
        apt-get)
            if sudo apt-get install -y \
                curl \
                wget \
                git \
                zsh \
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
                pkg-config; then
                record_success "Essential packages, asdf dependencies, and zsh installed"
            else
                record_failure "Failed to install essential packages"
                return 1
            fi
            ;;
        yum|dnf)
            if sudo $PKG_MANAGER install -y \
                curl \
                wget \
                git \
                zsh \
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
                pkgconfig; then
                record_success "Essential packages, asdf dependencies, and zsh installed"
            else
                record_failure "Failed to install essential packages"
                return 1
            fi
            ;;
        pacman)
            if sudo pacman -S --needed --noconfirm \
                curl \
                wget \
                git \
                zsh \
                base-devel \
                file \
                procfs-ng \
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
                pkgconfig; then
                record_success "Essential packages, asdf dependencies, and zsh installed"
            else
                record_failure "Failed to install essential packages"
                return 1
            fi
            ;;
    esac
}

# Switch to zsh early in the process
switch_to_zsh() {
    log_info "Switching to zsh for the remainder of the bootstrap process..."
    
    if ! command_exists zsh; then
        log_error "zsh not found, cannot switch shells"
        record_failure "zsh not available for shell switch"
        return 1
    fi
    
    # Export that we're now running in zsh context
    export BOOTSTRAP_SHELL="zsh"
    
    # Set zsh as the shell for the rest of the script
    if [[ "$0" != *"zsh"* ]]; then
        log_info "Re-executing script with zsh..."
        # Re-execute the script with zsh, passing all current environment
        exec zsh "$0" "$@"
    fi
    
    record_success "Successfully switched to zsh"
}

# Download configuration files
download_config_files() {
    log_info "Downloading configuration files..."
    
    local config_base_url="${CONFIG_BASE_URL:-https://raw.githubusercontent.com/securityclippy/bootstrap/main/config}"
    local config_dir="$HOME/.bootstrap-config"
    
    mkdir -p "$config_dir"
    
    # List of config files to download
    local config_files=(
        "asdf_languages_config.txt"
        "brew_packages_config.txt"
        "additional_packages_config.txt"
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
    
    record_success "Configuration files download process completed"
}

# Install asdf
install_asdf() {
    if brew install asdf; then
        record_success "asdf installed successfully"
    else
        record_failure "Failed to install asdf"
        return 1
    fi
}

# Install asdf plugins and tools from .tool-versions
install_asdf_tools() {
    log_info "Installing development tools via asdf..."
    
    # Source asdf
    export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
    . "$HOME/.asdf/asdf.sh"
    
    local config_file="$HOME/.bootstrap-config/asdf_languages_config.txt"
    local tool_versions_file=""
    
    # Use downloaded config or fall back to local or defaults
    if [[ -f "$config_file" ]]; then
        tool_versions_file="$config_file"
        log_info "Using asdf config from downloaded file"
    elif [[ -f "config/asdf_languages_config.txt" ]]; then
        tool_versions_file="config/asdf_languages_config.txt"
        log_info "Using asdf config from local directory"
    elif [[ -f ".tool-versions" ]]; then
        tool_versions_file=".tool-versions"
        log_info "Using .tool-versions from current directory"
    else
        log_warning "No asdf config found, creating default configuration"
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
    
    # Parse config file and install plugins
    local tools=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Extract tool name - handle both formats: "tool:version" and "tool version"
        local tool
        if [[ "$line" =~ : ]]; then
            # Format: language:version
            tool=$(echo "$line" | cut -d: -f1)
        else
            # Format: language version
            tool=$(echo "$line" | awk '{print $1}')
        fi
        [[ -n "$tool" ]] && tools+=("$tool")
    done < "$tool_versions_file"
    
    # Install plugins for all tools
    local failed_plugins=()
    for tool in "${tools[@]}"; do
        if ! asdf plugin list | grep -q "^$tool$"; then
            log_info "Adding asdf plugin: $tool"
            if asdf plugin add "$tool"; then
                log_success "Added plugin: $tool"
            else
                log_warning "Failed to add plugin: $tool (may not exist)"
                failed_plugins+=("$tool")
            fi
        else
            log_info "Plugin $tool already installed"
        fi
    done
    
    # Convert config to .tool-versions format if needed and install tools
    if [[ -f "$tool_versions_file" ]]; then
        log_info "Installing tools from $tool_versions_file..."
        
        # If using the language:version format, convert to .tool-versions format
        if [[ "$tool_versions_file" == *"asdf_languages_config.txt" ]]; then
            local temp_tool_versions="/tmp/.tool-versions"
            while IFS= read -r line; do
                # Skip empty lines and comments
                [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
                
                # Convert language:version to language version
                if [[ "$line" =~ : ]]; then
                    echo "$line" | sed 's/:/ /' >> "$temp_tool_versions"
                else
                    echo "$line" >> "$temp_tool_versions"
                fi
            done < "$tool_versions_file"
            
            # Install from converted file
            cd /tmp
            if asdf install; then
                record_success "All asdf tools installed successfully"
            else
                record_failure "Some asdf tools failed to install"
            fi
            rm -f "$temp_tool_versions"
        else
            # Use file as-is
            cd "$(dirname "$tool_versions_file")"
            if asdf install; then
                record_success "All asdf tools installed successfully"
            else
                record_failure "Some asdf tools failed to install"
            fi
        fi
    fi
    
    if [[ ${#failed_plugins[@]} -gt 0 ]]; then
        record_failure "Failed to install asdf plugins: ${failed_plugins[*]}"
    fi
    
    log_info "asdf tools installation process completed"
}

# Install Homebrew (for system tools only)
install_homebrew() {
    if command_exists brew; then
        log_info "Homebrew already installed, updating..."
        if brew update; then
            record_success "Homebrew updated"
        else
            record_failure "Failed to update Homebrew"
            return 1
        fi
        return
    fi
    
    log_info "Installing Homebrew for system tools..."
    
    # Install Homebrew
    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        # Add Homebrew to PATH for current session
        if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        
        # Add to shell profile
        SHELL_PROFILE=""
        if [[ -n "$ZSH_VERSION" || "$BOOTSTRAP_SHELL" == "zsh" ]]; then
            SHELL_PROFILE="$HOME/.zshrc"
            # Ensure .zshrc exists
            if [[ ! -f "$SHELL_PROFILE" ]]; then
                touch "$SHELL_PROFILE"
                log_info "Created $SHELL_PROFILE"
            fi
        elif [[ -n "$BASH_VERSION" ]]; then
            SHELL_PROFILE="$HOME/.bashrc"
        fi
        
        if [[ -n "$SHELL_PROFILE" && -f "$SHELL_PROFILE" ]]; then
            if ! grep -q "linuxbrew" "$SHELL_PROFILE"; then
                echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$SHELL_PROFILE"
                log_info "Added Homebrew to $SHELL_PROFILE"
            fi
        fi
        
        record_success "Homebrew installed successfully"
    else
        record_failure "Failed to install Homebrew"
        return 1
    fi
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
    
    local config_file="$HOME/.bootstrap-config/brew_packages_config.txt"
    local packages=()
    
    # Read packages from file or use defaults
    if [[ -f "$config_file" ]]; then
        log_info "Reading Homebrew packages from $config_file"
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            packages+=("$line")
        done < "$config_file"
    elif [[ -f "config/brew_packages_config.txt" ]]; then
        log_info "Reading Homebrew packages from local config"
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            packages+=("$line")
        done < "config/brew_packages_config.txt"
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
            "git-lfs"         # Git Large File Storage
            "lazygit"         # Git TUI
            "docker-compose"  # Container orchestration
        )
    fi
    
    local failed_packages=()
    for package in "${packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            log_info "$package already installed"
        else
            log_info "Installing $package..."
            if brew install "$package"; then
                log_success "Installed $package"
            else
                log_error "Failed to install $package"
                failed_packages+=("$package")
            fi
        fi
    done
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        record_success "All system tools installed successfully"
    else
        record_failure "Failed to install system tools: ${failed_packages[*]}"
    fi
}

# Install additional system packages from additional-packages.txt
install_additional_packages() {
    log_info "Installing additional system packages..."
    
    local config_file="$HOME/.bootstrap-config/additional_packages_config.txt"
    
    if [[ -f "$config_file" ]]; then
        log_info "Using downloaded additional packages config"
    elif [[ -f "config/additional_packages_config.txt" ]]; then
        config_file="config/additional_packages_config.txt"
        log_info "Using local additional packages config"
    else
        log_info "No additional packages config found, skipping additional packages"
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
            if sudo apt-get install -y "${packages[@]}"; then
                record_success "Additional system packages installed"
            else
                record_failure "Failed to install additional system packages"
            fi
            ;;
        yum|dnf)
            if sudo $PKG_MANAGER install -y "${packages[@]}"; then
                record_success "Additional system packages installed"
            else
                record_failure "Failed to install additional system packages"
            fi
            ;;
        pacman)
            if sudo pacman -S --needed --noconfirm "${packages[@]}"; then
                record_success "Additional system packages installed"
            else
                record_failure "Failed to install additional system packages"
            fi
            ;;
    esac
}


# Install oh-my-zsh
install_ohmyzsh() {
    log_info "Installing oh-my-zsh..."
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log_info "oh-my-zsh already installed"
        record_success "oh-my-zsh already installed"
        return
    fi
    
    # Ensure .zshrc exists before installing oh-my-zsh
    if [[ ! -f "$HOME/.zshrc" ]]; then
        touch "$HOME/.zshrc"
        log_info "Created initial .zshrc file"
    fi
    
    # Install oh-my-zsh
    if RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
        record_success "oh-my-zsh installed successfully"
    else
        record_failure "Failed to install oh-my-zsh"
    fi
}

# Set zsh as default shell
set_default_shell() {
    log_info "Setting zsh as default shell..."
    
    # Check if zsh is available
    if ! command_exists zsh; then
        log_error "zsh not found, please install it first"
        return 1
    fi
    
    # Get current shell
    current_shell=$(getent passwd "$USER" | cut -d: -f7)
    zsh_path=$(which zsh)
    
    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_info "zsh is already the default shell"
        return
    fi
    
    # Change default shell
    if chsh -s "$zsh_path"; then
        record_success "Default shell changed to zsh"
        log_info "Please log out and log back in for the change to take effect"
    else
        record_failure "Failed to change default shell to zsh"
        log_warning "You may need to run 'chsh -s $(which zsh)' manually"
    fi
}

# Configure shell for optimal asdf performance and tab completions
configure_shell() {
    log_info "Configuring shell for optimal asdf performance and tab completions..."
    
    # Configure zsh - ensure .zshrc exists first
    if [[ ! -f "$HOME/.zshrc" ]]; then
        touch "$HOME/.zshrc"
        log_info "Created .zshrc file for configuration"
    fi
    
    if [[ -f "$HOME/.zshrc" ]]; then
        SHELL_PROFILE="$HOME/.zshrc"
        
        # Add asdf and tool configurations
        if ! grep -q "asdf completions" "$SHELL_PROFILE"; then
            cat >> "$SHELL_PROFILE" << 'EOF'

# asdf configuration
. "$HOME/.asdf/asdf.sh"
fpath=(${ASDF_DIR}/completions $fpath)
autoload -Uz compinit && compinit

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

# Tab completions for installed tools
if command -v gh &> /dev/null; then
    eval "$(gh completion -s zsh)"
fi

if command -v kubectl &> /dev/null; then
    source <(kubectl completion zsh)
fi

if command -v helm &> /dev/null; then
    source <(helm completion zsh)
fi

if command -v terraform &> /dev/null; then
    complete -o nospace -C terraform terraform
fi

if command -v docker &> /dev/null; then
    if [[ -f /usr/share/zsh/vendor-completions/_docker ]]; then
        source /usr/share/zsh/vendor-completions/_docker
    fi
fi

if command -v docker-compose &> /dev/null; then
    if [[ -f /usr/share/zsh/vendor-completions/_docker-compose ]]; then
        source /usr/share/zsh/vendor-completions/_docker-compose
    fi
fi

# fzf key bindings and completion
if command -v fzf &> /dev/null; then
    eval "$(fzf --zsh)"
fi

# Initialize completion system
compinit
EOF
            record_success "Added asdf and completions configuration to zsh"
        fi
    fi
    
    # Configure bash as fallback
    if [[ -f "$HOME/.bashrc" ]]; then
        BASH_PROFILE="$HOME/.bashrc"
        
        if ! grep -q "asdf completions" "$BASH_PROFILE"; then
            cat >> "$BASH_PROFILE" << 'EOF'

# asdf configuration
. "$HOME/.asdf/asdf.sh"
. "$HOME/.asdf/completions/asdf.bash"

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

# Tab completions for installed tools
if command -v gh &> /dev/null; then
    eval "$(gh completion -s bash)"
fi

if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
fi

if command -v helm &> /dev/null; then
    source <(helm completion bash)
fi

if command -v terraform &> /dev/null; then
    complete -C terraform terraform
fi

# fzf key bindings and completion
if command -v fzf &> /dev/null; then
    eval "$(fzf --bash)"
fi
EOF
            record_success "Added asdf and completions configuration to bash"
        fi
    fi
    
    record_success "Shell configuration completed"
}

# Print installation summary
print_summary() {
    log_info ""
    log_info "========================================="
    log_info "           INSTALLATION SUMMARY"
    log_info "========================================="
    
    if [[ ${#SUCCEEDED_STEPS[@]} -gt 0 ]]; then
        log_info ""
        log_success "✅ SUCCESSFUL STEPS (${#SUCCEEDED_STEPS[@]}):"
        for step in "${SUCCEEDED_STEPS[@]}"; do
            echo -e "  ${GREEN}✓${NC} $step"
        done
    fi
    
    if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
        log_info ""
        log_error "❌ FAILED STEPS (${#FAILED_STEPS[@]}):"
        for step in "${FAILED_STEPS[@]}"; do
            echo -e "  ${RED}✗${NC} $step"
        done
        log_info ""
        log_warning "Some installations failed. You may need to:"
        log_warning "- Check your internet connection"
        log_warning "- Verify system dependencies"
        log_warning "- Run the script again"
        log_warning "- Install failed components manually"
    else
        log_info ""
        log_success "🎉 All installations completed successfully!"
    fi
    
    log_info ""
    log_info "========================================="
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
    log_info "Script will continue even if individual installations fail"
    
    # Track overall success/failure
    local overall_success=true
    
    check_linux_distro || overall_success=false
    download_config_files || overall_success=false
    update_system || overall_success=false
    install_essentials || overall_success=false
    switch_to_zsh || overall_success=false
    install_homebrew || overall_success=false
    install_system_tools || overall_success=false
    install_asdf || overall_success=false
    install_asdf_tools || overall_success=false
    install_additional_packages || overall_success=false
    install_ohmyzsh || overall_success=false
    set_default_shell || overall_success=false
    configure_shell || overall_success=false
    validate_installation || overall_success=false
    
    # Print comprehensive summary
    print_summary
    
    if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
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
    else
        log_warning "Bootstrap completed with ${#FAILED_STEPS[@]} failures"
        log_info "See the summary above for details on what failed"
        log_info "You can re-run this script to retry failed installations"
        
        # Exit with error code to indicate partial failure
        exit 1
    fi
}

# Run main function
main "$@"
