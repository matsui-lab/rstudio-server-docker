#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  RStudio Server Docker Setup${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect platform
detect_platform() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            DOCKER_PLATFORM="linux/amd64"
            ;;
        arm64|aarch64)
            DOCKER_PLATFORM="linux/arm64"
            ;;
        *)
            print_warning "Unknown architecture: $ARCH. Defaulting to linux/amd64"
            DOCKER_PLATFORM="linux/amd64"
            ;;
    esac
    print_success "Detected platform: $DOCKER_PLATFORM"
}

# Check Docker installation
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        echo "  - Mac: https://docs.docker.com/desktop/install/mac-install/"
        echo "  - Linux: https://docs.docker.com/engine/install/"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi

    print_success "Docker is installed and running"

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed."
        exit 1
    fi
    print_success "Docker Compose is available"
}

# Get user input
get_config() {
    echo ""
    echo -e "${BLUE}--- Configuration ---${NC}"
    echo ""

    # Number of instances
    read -p "Number of RStudio instances [1-10, default: 5]: " INSTANCES
    INSTANCES=${INSTANCES:-5}
    if ! [[ "$INSTANCES" =~ ^[0-9]+$ ]] || [ "$INSTANCES" -lt 1 ] || [ "$INSTANCES" -gt 10 ]; then
        print_error "Invalid number. Using default: 5"
        INSTANCES=5
    fi

    # Base port
    read -p "Base port [default: 8787]: " BASE_PORT
    BASE_PORT=${BASE_PORT:-8787}

    # SSH key handling
    echo ""
    echo "SSH key options:"
    echo "  1) Copy existing keys from ~/.ssh"
    echo "  2) Generate new SSH key pair"
    echo "  3) Skip SSH setup"
    read -p "Choose [1-3, default: 1]: " SSH_OPTION
    SSH_OPTION=${SSH_OPTION:-1}

    # Claude config sharing
    echo ""
    read -p "Share Claude config from host ~/.claude? [Y/n]: " SHARE_CLAUDE
    SHARE_CLAUDE=${SHARE_CLAUDE:-Y}
    if [[ "$SHARE_CLAUDE" =~ ^[Yy]$ ]]; then
        SHARE_CLAUDE_CONFIG=true
    else
        SHARE_CLAUDE_CONFIG=false
    fi

    # Include runner
    read -p "Include runner container for batch processing? [Y/n]: " INCLUDE_RUNNER
    INCLUDE_RUNNER=${INCLUDE_RUNNER:-Y}
    if [[ "$INCLUDE_RUNNER" =~ ^[Yy]$ ]]; then
        INCLUDE_RUNNER_CONTAINER=true
    else
        INCLUDE_RUNNER_CONTAINER=false
    fi

    # GitHub PAT setup
    echo ""
    echo -e "${BLUE}--- GitHub Authentication ---${NC}"
    echo "A Personal Access Token (PAT) enables git/gh commands in containers."
    echo "Create one at: https://github.com/settings/tokens"
    echo "Required scopes: repo, read:org, workflow"
    echo ""
    read -p "Setup GitHub PAT? [Y/n]: " SETUP_PAT
    SETUP_PAT=${SETUP_PAT:-Y}
    if [[ "$SETUP_PAT" =~ ^[Yy]$ ]]; then
        read -p "GitHub username: " GITHUB_USERNAME
        read -sp "GitHub PAT (input hidden): " GITHUB_TOKEN
        echo ""
        SETUP_GITHUB_AUTH=true
    else
        GITHUB_USERNAME=""
        GITHUB_TOKEN=""
        SETUP_GITHUB_AUTH=false
    fi
}

# Setup SSH keys
setup_ssh() {
    mkdir -p ssh
    chmod 700 ssh

    case $SSH_OPTION in
        1)
            if [ -f ~/.ssh/id_ed25519 ]; then
                cp ~/.ssh/id_ed25519 ssh/
                cp ~/.ssh/id_ed25519.pub ssh/
                print_success "Copied existing SSH keys"
            elif [ -f ~/.ssh/id_rsa ]; then
                cp ~/.ssh/id_rsa ssh/
                cp ~/.ssh/id_rsa.pub ssh/
                print_success "Copied existing SSH keys (RSA)"
            else
                print_warning "No existing SSH keys found. Generating new ones..."
                SSH_OPTION=2
            fi
            ;;
        2)
            ;;
        3)
            print_warning "Skipping SSH setup. Git over SSH will not work."
            return
            ;;
    esac

    if [ "$SSH_OPTION" = "2" ]; then
        read -p "Enter email for SSH key: " SSH_EMAIL
        ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f ssh/id_ed25519 -N ""
        print_success "Generated new SSH key pair"
        echo ""
        echo -e "${YELLOW}Add this public key to your GitHub account:${NC}"
        cat ssh/id_ed25519.pub
        echo ""
    fi

    # Create SSH config
    cat > ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
EOF

    # Set permissions
    chmod 600 ssh/id_ed25519 2>/dev/null || true
    chmod 644 ssh/id_ed25519.pub 2>/dev/null || true
    chmod 644 ssh/config
}

# Create home directories
create_home_dirs() {
    for i in $(seq 1 $INSTANCES); do
        LETTER=$(echo $i | awk '{printf "%c", 96+$1}')
        mkdir -p "home_$LETTER"
        mkdir -p "home_$LETTER/.config/rstudio"
        cp config/rstudio-prefs.json "home_$LETTER/.config/rstudio/"
    done
    print_success "Created home directories for $INSTANCES instances"
}

# Setup GitHub authentication (git credentials + gh)
setup_github_auth() {
    if [ "$SETUP_GITHUB_AUTH" != true ]; then
        return
    fi

    for i in $(seq 1 $INSTANCES); do
        LETTER=$(echo $i | awk '{printf "%c", 96+$1}')
        HOME_DIR="home_$LETTER"

        # Create .git-credentials file
        echo "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com" > "$HOME_DIR/.git-credentials"
        chmod 600 "$HOME_DIR/.git-credentials"

        # Create .gitconfig with credential helper
        cat > "$HOME_DIR/.gitconfig" << GITEOF
[user]
    name = ${GITHUB_USERNAME}
    email = ${GITHUB_USERNAME}@users.noreply.github.com
[credential]
    helper = store
[init]
    defaultBranch = main
GITEOF

        # Create gh config directory and hosts.yml for gh CLI
        mkdir -p "$HOME_DIR/.config/gh"
        cat > "$HOME_DIR/.config/gh/hosts.yml" << GHEOF
github.com:
    oauth_token: ${GITHUB_TOKEN}
    user: ${GITHUB_USERNAME}
    git_protocol: https
GHEOF
        chmod 600 "$HOME_DIR/.config/gh/hosts.yml"
    done

    print_success "Configured GitHub authentication for all instances"
}

# Generate docker-compose.yml
generate_compose() {
    cat > docker-compose.yml << EOF
# Auto-generated by setup.sh
# Instances: $INSTANCES, Platform: $DOCKER_PLATFORM

services:
EOF

    # Generate service entries
    for i in $(seq 1 $INSTANCES); do
        LETTER=$(echo $i | awk '{printf "%c", 96+$1}')
        PORT=$((BASE_PORT + i - 1))

        cat >> docker-compose.yml << EOF
  rstudio_$LETTER:
    build: .
    container_name: rstudio-server-$LETTER
    hostname: rstudio-$LETTER
    platform: $DOCKER_PLATFORM
    ports: ["$PORT:8787"]
    environment:
      USER: rstudio_$LETTER
      PASSWORD: rstudio_$LETTER
      RETICULATE_PYTHON: /opt/venv/bin/python
      RENV_PATHS_CACHE: /opt/renv/cache
      RENV_PATHS_LIBRARY: /opt/renv/library
    volumes:
      - ./home_$LETTER:/home/rstudio_$LETTER
      - ./ssh:/home/rstudio_$LETTER/.ssh:ro
EOF

        if [ "$SHARE_CLAUDE_CONFIG" = true ]; then
            echo "      - ~/.claude:/home/rstudio_$LETTER/.claude" >> docker-compose.yml
        fi

        cat >> docker-compose.yml << EOF
      - renv-cache:/opt/renv/cache
      - renv-lib:/opt/renv/library
    working_dir: /home/rstudio_$LETTER
    restart: unless-stopped

EOF
    done

    # Add runner container if requested
    if [ "$INCLUDE_RUNNER_CONTAINER" = true ]; then
        cat >> docker-compose.yml << EOF
  runner:
    build: .
    container_name: rstudio-runner
    hostname: rstudio-runner
    platform: $DOCKER_PLATFORM
    environment:
      RETICULATE_PYTHON: /opt/venv/bin/python
      RENV_PATHS_CACHE: /opt/renv/cache
      RENV_PATHS_LIBRARY: /opt/renv/library
    volumes:
EOF
        for i in $(seq 1 $INSTANCES); do
            LETTER=$(echo $i | awk '{printf "%c", 96+$1}')
            echo "      - ./home_$LETTER:/home/rstudio_$LETTER" >> docker-compose.yml
        done

        if [ "$SHARE_CLAUDE_CONFIG" = true ]; then
            echo "      - ~/.claude:/home/rstudio/.claude" >> docker-compose.yml
        fi

        cat >> docker-compose.yml << EOF
      - renv-cache:/opt/renv/cache
      - renv-lib:/opt/renv/library
    working_dir: /home
    entrypoint: ["bash", "-lc"]
    tty: true
    restart: unless-stopped

EOF
    fi

    # Add volumes
    cat >> docker-compose.yml << EOF
volumes:
  renv-cache:
  renv-lib:
EOF

    print_success "Generated docker-compose.yml"
}

# Save configuration to .env
save_env() {
    cat > .env << EOF
# Generated configuration
RSTUDIO_INSTANCES=$INSTANCES
RSTUDIO_BASE_PORT=$BASE_PORT
SHARE_CLAUDE_CONFIG=$SHARE_CLAUDE_CONFIG
INCLUDE_RUNNER=$INCLUDE_RUNNER_CONTAINER
DOCKER_PLATFORM=$DOCKER_PLATFORM
EOF
    print_success "Saved configuration to .env"
}

# Setup /etc/hosts entries for session isolation
setup_hosts() {
    echo ""
    echo -e "${BLUE}--- /etc/hosts Setup ---${NC}"
    echo "Adding hostname entries to /etc/hosts enables independent sessions."
    echo "This requires sudo privileges."
    echo ""

    read -p "Add entries to /etc/hosts? [Y/n]: " SETUP_HOSTS
    SETUP_HOSTS=${SETUP_HOSTS:-Y}

    if [[ ! "$SETUP_HOSTS" =~ ^[Yy]$ ]]; then
        print_warning "Skipping /etc/hosts setup."
        echo "You can manually add the following entries later:"
        for i in $(seq 1 $INSTANCES); do
            LETTER=$(echo $i | awk '{printf "%c", 96+$1}')
            echo "  127.0.0.1 rstudio-$LETTER"
        done
        return
    fi

    # Check if entries already exist and add missing ones
    HOSTS_TO_ADD=""
    for i in $(seq 1 $INSTANCES); do
        LETTER=$(echo $i | awk '{printf "%c", 96+$1}')
        HOSTNAME="rstudio-$LETTER"
        if ! grep -q "^127\.0\.0\.1[[:space:]]*$HOSTNAME\$" /etc/hosts 2>/dev/null; then
            HOSTS_TO_ADD="$HOSTS_TO_ADD\n127.0.0.1 $HOSTNAME"
        fi
    done

    if [ -z "$HOSTS_TO_ADD" ]; then
        print_success "All hostname entries already exist in /etc/hosts"
        return
    fi

    echo ""
    echo "The following entries will be added to /etc/hosts:"
    echo -e "$HOSTS_TO_ADD"
    echo ""

    # Add entries with sudo
    echo -e "$HOSTS_TO_ADD" | sudo tee -a /etc/hosts > /dev/null
    if [ $? -eq 0 ]; then
        print_success "Added hostname entries to /etc/hosts"
    else
        print_error "Failed to update /etc/hosts. Please add entries manually."
    fi
}

# Build and start
build_and_start() {
    echo ""
    read -p "Build and start containers now? [Y/n]: " BUILD_NOW
    BUILD_NOW=${BUILD_NOW:-Y}

    if [[ "$BUILD_NOW" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}Building Docker images...${NC}"
        docker compose build

        echo ""
        echo -e "${BLUE}Starting containers...${NC}"
        docker compose up -d

        echo ""
        print_success "Containers started successfully!"
        echo ""
        echo -e "${GREEN}Access RStudio Server:${NC}"
        for i in $(seq 1 $INSTANCES); do
            LETTER=$(echo $i | awk '{printf "%c", 96+$1}')
            PORT=$((BASE_PORT + i - 1))
            echo "  - Instance $LETTER: http://rstudio-$LETTER:$PORT"
            echo "    Username: rstudio_$LETTER"
            echo "    Password: rstudio_$LETTER"
        done
        echo ""
        echo -e "${YELLOW}Note: Use hostname URLs (rstudio-X) for independent sessions${NC}"
    else
        echo ""
        echo "To build and start later, run:"
        echo "  docker compose build && docker compose up -d"
    fi
}

# Main
print_header
detect_platform
check_docker
get_config
setup_ssh
create_home_dirs
setup_github_auth
generate_compose
save_env
setup_hosts
build_and_start

echo ""
print_success "Setup complete!"
