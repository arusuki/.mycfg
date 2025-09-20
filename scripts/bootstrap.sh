#!/bin/bash
set -e
current=$(pwd)
cd $HOME

cleanup() {
    if [ -n "$current" ]; then
        cd "$current"
    fi }

trap cleanup EXIT

# clone bare repo
git clone --bare https://github.com/arusuki/.mycfg.git .mycfg
alias config="/usr/bin/git --git-dir=$HOME/.mycfg/ --work-tree=$HOME"
config config --local status.showUntrackedFiles no
config checkout
config submodule update --init

# install tmux plugins
TPM_PATH="$HOME/.tmux/plugins/tpm"
if [ -f "$TPM_PATH/bin/install_plugins" ]; then
  echo "Installing tmux plugins..."
  $TPM_PATH/bin/install_plugins
  echo "Tmux plugins installation process triggered."
  echo "Note: You might need to source your ~/.tmux.conf or restart tmux for changes to take effect."
else
  echo "Error: tpm install script not found at $TPM_PATH/bin/install_plugins"
  exit 1
fi

# install mise
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if ! command -v mise &> /dev/null; then
    echo -e "${RED}installing mise...${NC}"
    curl https://mise.run | sh
    export PATH=$PATH:$HOME/.local/bin
fi

tools=(
  "node"
  "python"
  "neovim"
  "tmux"
  "fd"
  "fzf"
  "ripgrep"
)


for tool in "${tools[@]}"; do
    echo -e "--------------------------------------------------"
    echo -e "${YELLOW}[mise] installing: ${tool}...${NC}"
    if mise use -g "$tool"; then
        echo -e "${GREEN}installed: ${tool}${NC}"
    else
        echo -e "${RED}failed to install: ${tool}${NC}"
    fi
done
