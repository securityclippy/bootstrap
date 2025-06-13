# Linux Development Environment Bootstrap

An idempotent bootstrap script for setting up a consistent Linux development environment using **asdf** for development tools and **Homebrew** for system utilities.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/securityclippy/bootstrap/main/bootstrap.sh | bash
```

## Architecture

This bootstrap script uses a **hybrid approach** for optimal tool management:

- **asdf**: Manages development tools that require version control (Node.js, Python, Go, etc.)
- **Homebrew**: Manages system utilities that don't need project-specific versions (git, curl, etc.)

### Why This Approach?

- **Reproducible environments**: `.tool-versions` ensures exact same versions across team
- **Project flexibility**: Different projects can use different language versions
- **CI/CD integration**: Easy to replicate environments in containers and pipelines
- **System stability**: System tools via Homebrew for better integration

## Repository Structure

```
your-repo/
├── bootstrap.sh              # Main bootstrap script
├── README.md                # This file
└── config/
    ├── .tool-versions        # asdf tools and versions
    ├── brew-packages.txt     # System tools via Homebrew
    └── additional-packages.txt # System packages via apt/yum
```

## Configuration Files

### `.tool-versions`
Defines exact versions for development tools managed by asdf:
```
nodejs 22.11.0
python 3.13.4
ruby 3.4.4
golang 1.24.4
terraform 1.5.2
```

### `brew-packages.txt`
System utilities installed via Homebrew:
```
gh
git-lfs
tree
htop
bat
ripgrep
fzf
neovim
tmux
```

### `additional-packages.txt`
System packages via native package manager:
```
net-tools
sqlite3
ffmpeg
postgresql-client
```

## Usage

### Standard Installation
```bash
curl -fsSL https://raw.githubusercontent.com/securityclippy/bootstrap/main/bootstrap.sh | bash
```

### Custom Configuration URL
```bash
CONFIG_BASE_URL=https://raw.githubusercontent.com/yourteam/configs/main \
curl -fsSL https://raw.githubusercontent.com/securityclippy/bootstrap/main/bootstrap.sh | bash
```

### Local Development
```bash
# Clone the repository
git clone https://github.com/securityclippy/bootstrap.git
cd bootstrap

# Run locally
./bootstrap.sh
```

## What Gets Installed

### Core System
- Essential build tools and dependencies
- Git configuration
- Development directories (`~/dev`, `~/dev/projects`, etc.)

### Development Tools (via asdf)
- **Languages**: Node.js, Python, Ruby, Go, Java
- **DevOps**: Terraform, kubectl, Helm, Docker Compose
- **Utilities**: jq, yq, shellcheck, direnv

### System Tools (via Homebrew)
- **CLI Tools**: GitHub CLI, tree, htop, bat, ripgrep, fzf
- **Development**: Neovim, tmux, git-lfs, lazygit
- **Optional**: GUI applications (VS Code, Docker Desktop, etc.)

## Team Usage

### Setting Up Your Team
1. Fork this repository
2. Customize the configuration files in `config/`
3. Update the URLs in the bootstrap script
4. Share the installation command with your team

### Project-Specific Versions
Create a `.tool-versions` file in your project root:
```bash
cd your-project
echo "nodejs 20.11.0" >> .tool-versions
echo "python 3.12.7" >> .tool-versions
asdf install
```

### Auto-Installation Hook
The script configures your shell to automatically install tools when entering directories with `.tool-versions`:
```bash
cd project-with-tool-versions/
# 🔧 Installing tools from .tool-versions...
# ✅ nodejs 20.11.0 is already installed
# ✅ python 3.12.7 is already installed
```

## Advanced Usage

### Version Management Commands
```bash
# List all available versions
asdf list all nodejs

# Install specific version
asdf install nodejs 20.11.0

# Set global default
asdf global nodejs 22.11.0

# Set project-specific version
asdf local python 3.12.7

# Show current versions
asdf current
```

### Adding New Tools
1. Add plugin: `asdf plugin add <tool-name>`
2. Update `.tool-versions`: `echo "<tool-name> <version>" >> .tool-versions`
3. Install: `asdf install`

### CI/CD Integration

#### GitHub Actions
```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/install@v4
      - run: npm test
```

#### Docker
```dockerfile
FROM ubuntu:22.04

# Install bootstrap script
RUN curl -fsSL https://raw.githubusercontent.com/securityclippy/bootstrap/main/bootstrap.sh | bash

# Your app code
COPY . /app
WORKDIR /app
RUN asdf install
```

## Troubleshooting

### Common Issues

**asdf command not found**
```bash
# Restart your shell or source the profile
source ~/.bashrc  # or ~/.zshrc
```

**Plugin installation fails**
```bash
# Update asdf plugin repository
asdf plugin update --all
```

**Tool compilation fails**
```bash
# Install additional dependencies
sudo apt-get install -y libssl-dev libreadline-dev
```

**Path conflicts**
```bash
# Check tool resolution order
type -a python
# Should show asdf shim first: ~/.asdf/shims/python
```

### Performance Optimization

If you experience slow shell startup, install asdf-direnv:
```bash
asdf plugin add direnv
asdf install direnv latest
asdf global direnv latest

# Add to .envrc in projects
echo "use asdf" > .envrc
direnv allow
```

## Security

- All downloads use HTTPS
- Script verifies checksums where possible
- Minimal sudo usage (only for system packages)
- No arbitrary code execution from external sources

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes on a clean Linux system
4. Submit a pull request

### Testing Locally
```bash
# Test in a Docker container
docker run -it --rm ubuntu:22.04 bash
curl -fsSL https://raw.githubusercontent.com/securityclippy/bootstrap/main/bootstrap.sh | bash

# Test with Vagrant
vagrant init ubuntu/jammy64
vagrant up
vagrant ssh
curl -fsSL https://raw.githubusercontent.com/securityclippy/bootstrap/main/bootstrap.sh | bash
```

## Migration Guide

### From Homebrew-Only Setup
If you're currently using Homebrew for everything:

1. **Run the new bootstrap script** - it will install asdf alongside Homebrew
2. **Verify installations work** - check that both `brew` and `asdf` commands work
3. **Migrate gradually** - start with one language (e.g., Node.js):
   ```bash
   # Check current version
   node --version
   
   # Install via asdf
   asdf install nodejs 22.11.0
   asdf global nodejs 22.11.0
   
   # Verify asdf version is active
   which node  # Should show ~/.asdf/shims/node
   ```
4. **Remove Homebrew versions** once asdf versions are working:
   ```bash
   brew uninstall node
   ```

### From Manual Installations
If you have manually installed tools:

1. **Check current versions**:
   ```bash
   node --version
   python3 --version
   go version
   ```
2. **Run bootstrap script** - it will install asdf with matching or newer versions
3. **Update your PATH** to prioritize asdf shims:
   ```bash
   echo 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```
4. **Verify asdf takes precedence**:
   ```bash
   which node  # Should show ~/.asdf/shims/node
   ```

## Customization Examples

### Team-Specific Configuration

Create your own configuration repository:

```bash
# Fork this repo and customize config files
mkdir my-team-bootstrap
cd my-team-bootstrap

# Custom .tool-versions for your stack
cat > config/.tool-versions << 'EOF'
nodejs 20.11.0      # LTS for our React apps
python 3.11.9       # Required for ML pipeline
golang 1.21.6       # Microservices version
terraform 1.6.0     # Infrastructure version
kubectl 1.28.0      # K8s cluster version
EOF

# Custom Homebrew packages
cat > config/brew-packages.txt << 'EOF'
gh
tree
htop
ripgrep
your-internal-tool
EOF
```

### Per-Project Setup

Different projects can have different requirements:

```bash
# Frontend project
cd frontend-app
cat > .tool-versions << 'EOF'
nodejs 20.11.0
yarn 1.22.22
EOF

# Backend API
cd ../api-service
cat > .tool-versions << 'EOF'
golang 1.24.4
redis 7.2.5
postgres 16.4
EOF

# Data pipeline
cd ../data-pipeline
cat > .tool-versions << 'EOF'
python 3.13.4
terraform 1.5.2
kubectl 1.30.0
EOF
```

### Environment-Specific Overrides

Use environment variables for temporary overrides:

```bash
# Use different Node version temporarily
export ASDF_NODEJS_VERSION=18.19.0
node --version  # Shows 18.19.0

# Back to .tool-versions default
unset ASDF_NODEJS_VERSION
node --version  # Shows version from .tool-versions
```

## FAQ

### Q: Why not use Docker for everything?
**A:** Docker is great for deployment, but for local development you need:
- Fast file system access
- Easy debugging
- IDE integration
- Multiple language versions simultaneously

### Q: What about performance compared to Homebrew?
**A:** 
- **asdf**: 2-5ms overhead per command (due to shims)
- **Homebrew**: Direct binary execution
- **Mitigation**: Use asdf-direnv plugin for frequently-called commands

### Q: Can I use this on WSL?
**A:** Yes! The script detects Linux distributions and works perfectly on WSL2.

### Q: How do I update tool versions?
**A:**
```bash
# Update .tool-versions file
echo "nodejs 22.12.0" >> .tool-versions

# Install new version
asdf install nodejs 22.12.0

# Remove old version (optional)
asdf uninstall nodejs 22.11.0
```

### Q: What if a tool isn't available in asdf?
**A:** You have several options:
1. Check if a plugin exists: `asdf plugin list all | grep <tool>`
2. Install via Homebrew and add to `brew-packages.txt`
3. Install via system package manager and add to `additional-packages.txt`
4. Create a custom asdf plugin

### Q: How do I share this with my team?
**A:**
1. Fork this repository
2. Customize the config files for your team's needs
3. Update the URL in the bootstrap command
4. Share the one-liner with your team
5. Document team-specific tools in your internal wiki

## Support

- **Issues**: Report bugs and feature requests via GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Security**: Report security issues privately to [security@yourteam.com]

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [asdf-vm](https://asdf-vm.com/) for the excellent version manager
- [Homebrew](https://brew.sh/) for system package management
- The open source community for all the amazing tools