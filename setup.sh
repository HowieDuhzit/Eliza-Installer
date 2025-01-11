#!/bin/bash
set -e
set -o pipefail
NVM_VERSION="v0.39.1"
NODE_VERSION="23.3.0"
REPO_URL="https://github.com/elizaOS/eliza"
TMUX_SESSION="eliza"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
NC='\033[0m'; BOLD='\033[1m'
log_error() { gum style --foreground 1 "❌ ${1}"; }
log_success() { gum style --foreground 2 "✅ ${1}"; }
log_info() { gum style --foreground 4 "ℹ️  ${1}"; }
handle_error() { log_error "Error occurred in: $1"; log_error "Exit code: $2"; exit 1; }
trap 'handle_error "${BASH_SOURCE[0]}:${LINENO}" $?' ERR

install_gum() {
    if ! command -v gum &> /dev/null; then
        log_info "Installing gum for better UI..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
        sudo apt update && sudo apt install -y gum
    fi
}

show_welcome() {
    clear
    cat << "EOF"
Welcome to

 EEEEEE LL    IIII ZZZZZZZ  AAAA
 EE     LL     II      ZZ  AA  AA
 EEEE   LL     II    ZZZ   AAAAAA
 EE     LL     II   ZZ     AA  AA
 EEEEEE LLLLL IIII ZZZZZZZ AA  AA

Eliza is an open-source AI agent.
     Created by ai16z 2024.
EOF
    echo
    gum style --border double --align center --width 50 --margin "1 2" --padding "1 2" \
        "Installation Setup" "" "This script will set up Eliza for you"
}

install_dependencies() {
    gum spin --spinner dot --title "Installing system dependencies..." -- \
        sudo apt update && sudo apt install -y git curl python3 python3-pip make ffmpeg tmux
    log_success "Dependencies installed"
}

install_nvm() {
    if [ ! -d "$HOME/.nvm" ]; then
        gum spin --spinner dot --title "Installing NVM..." -- \
            curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        log_success "NVM installed"
    else
        log_info "NVM already installed"
    fi
}

setup_node() {
    gum spin --spinner dot --title "Setting up Node.js ${NODE_VERSION}..." -- \
        nvm install "${NODE_VERSION}" && nvm alias eliza "${NODE_VERSION}" && nvm use eliza
    gum spin --spinner dot --title "Installing pnpm..." -- npm install -g pnpm
    log_success "Node.js and pnpm setup complete"
}

clone_repository() {
    if [ ! -d "eliza" ]; then
        gum spin --spinner dot --title "Cloning Eliza repository..." -- git clone "${REPO_URL}" eliza
        cd eliza
        LATEST_TAG=$(git describe --tags --abbrev=0)
        git checkout "${LATEST_TAG}"
        log_success "Repository cloned and checked out to latest tag: ${LATEST_TAG}"
    else
        log_info "Eliza directory already exists"
        cd eliza
    fi
}

setup_environment() {
    [ ! -f .env ] && cp .env.example .env && log_success "Environment file created"
}

create_tmux_session() {
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        log_info "Creating new tmux session: $TMUX_SESSION"
        tmux new-session -d -s "$TMUX_SESSION"
        log_success "Tmux session created"
    else
        log_info "Tmux session already exists"
    fi
}

build_and_start() {
    gum spin --spinner dot --title "Installing project dependencies..." -- \
        pnpm clean && pnpm install --no-frozen-lockfile
    log_success "Dependencies installed"

    gum spin --spinner dot --title "Building project..." -- pnpm build
    log_success "Project built successfully"

    log_info "Starting Eliza services in tmux session..."
    tmux send-keys -t "$TMUX_SESSION" "cd $(pwd)" C-m
    tmux send-keys -t "$TMUX_SESSION" "export NVM_DIR=\"$HOME/.nvm\"" C-m
    tmux send-keys -t "$TMUX_SESSION" "[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"" C-m
    tmux send-keys -t "$TMUX_SESSION" "nvm use eliza" C-m
    tmux send-keys -t "$TMUX_SESSION" "pnpm start & pnpm start:client" C-m

    sleep 5

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "http://localhost:5173"
    elif command -v open >/dev/null 2>&1; then
        open "http://localhost:5173"
    else
        log_info "Please open http://localhost:5173 in your browser"
    fi
}

main() {
    install_gum
    show_welcome
    
    if ! gum confirm "Ready to install Eliza?"; then
        log_info "Installation cancelled"
        exit 0
    fi

    install_dependencies
    install_nvm
    setup_node
    clone_repository
    setup_environment
    create_tmux_session
    build_and_start

    gum style --border double --align center --width 50 --margin "1 2" --padding "1 2" \
        "🎉 Installation Complete!" "" "Eliza is now running in tmux session: $TMUX_SESSION" "" \
        "To attach to the session:" "tmux attach -t $TMUX_SESSION" "" \
        "To detach from session:" "Press Ctrl+b then d" "" \
        "Eliza is available at:" "http://localhost:5173"
}

main "$@"