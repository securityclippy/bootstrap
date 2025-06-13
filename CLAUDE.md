# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Linux development environment bootstrap script that provides an idempotent setup for development environments using a hybrid approach:
- **asdf**: Manages development tools requiring version control (Node.js, Python, Go, etc.)
- **Homebrew**: Manages system utilities that don't need project-specific versions (git, curl, etc.)

## Key Files

- `bootstrap.sh`: Main bootstrap script that orchestrates the entire setup process
- `config/asdf_languages_config.txt`: Defines development tools and versions managed by asdf
- `config/brew_packages_config.txt`: Lists system utilities installed via Homebrew
- `config/additional_packages_config.txt`: System packages installed via native package manager

## Script Architecture

The bootstrap script follows this execution flow:
1. **System Detection**: Detects Linux distribution (Debian/Ubuntu, RHEL/CentOS/Fedora, Arch)
2. **Configuration Download**: Downloads config files from GitHub (configurable via `CONFIG_BASE_URL`)
3. **System Setup**: Updates packages and installs essential build dependencies
4. **Tool Installation**: Installs Homebrew first, then system tools, then asdf and development tools
5. **Shell Enhancement**: Installs oh-my-zsh and sets zsh as default shell
6. **Shell Configuration**: Sets up auto-install hooks for `.tool-versions` files and tab completions
7. **Validation**: Verifies successful installation

## Development Commands

### Testing the Script
```bash
# Test locally
./bootstrap.sh

# Test in clean container
docker run -it --rm ubuntu:22.04 bash
curl -fsSL https://raw.githubusercontent.com/securityclippy/bootstrap/main/bootstrap.sh | bash
```

### Configuration Management
```bash
# Use custom configuration URL
CONFIG_BASE_URL=https://raw.githubusercontent.com/yourteam/configs/main ./bootstrap.sh

# Test with local config files
mkdir -p ~/.bootstrap-config
cp config/* ~/.bootstrap-config/
./bootstrap.sh
```

### Debugging
```bash
# Run with verbose output
bash -x bootstrap.sh

# Check specific components
asdf current
brew list
```

## Configuration File Formats

### asdf_languages_config.txt
- Format: `language:version` (one per line)
- Comments start with `#`
- Maps to asdf plugins and versions

### brew_packages_config.txt
- Format: `package_name` (one per line)
- Comments start with `#`
- Installed via `brew install`

### additional_packages_config.txt
- Format: `package_name` (one per line)
- Comments start with `#`
- Installed via system package manager (apt/yum/dnf/pacman)

## Important Implementation Details

### Error Handling
- Script uses `set -e` for fail-fast behavior
- Individual tool installations are wrapped in conditional checks
- Graceful fallbacks for missing configuration files

### Idempotency
- All operations check for existing installations before proceeding
- Safe to run multiple times without side effects
- Updates existing tools rather than reinstalling

### Shell Integration
- Installs oh-my-zsh for enhanced shell experience
- Sets zsh as default shell automatically
- Configures both zsh and bash profiles for compatibility
- Adds auto-install hooks for `.tool-versions` files
- Sets up proper PATH ordering (asdf shims first)
- Configures tab completions for all installed tools (gh, kubectl, helm, terraform, fzf, docker)

### Distribution Support
- Supports Debian/Ubuntu (apt-get)
- Supports RHEL/CentOS/Fedora (yum/dnf)
- Supports Arch Linux (pacman)
- Automatically detects and adapts to distribution

## Security Considerations

- All downloads use HTTPS
- Minimal sudo usage (only for system packages)
- No arbitrary code execution from external sources
- Verifies checksums where possible