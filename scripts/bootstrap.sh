#!/bin/bash
# requires following system dependencies: gcc g++ make curl zsh tmux[optional]

set -e
set -o pipefail

current=$(pwd)
cd $HOME
CONFIG="/usr/bin/git --git-dir=$HOME/.mycfg/ --work-tree=$HOME"

cleanup() {
    if [ -n "$current" ]; then
        cd "$current"
    fi
}

trap cleanup EXIT

# clone bare repo
if [ ! -d ".mycfg" ]; then
    git clone --bare https://github.com/arusuki/.mycfg.git .mycfg
    $CONFIG checkout
fi
$CONFIG config --local status.showUntrackedFiles no
$CONFIG submodule update --init

# install mise
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MISE=$HOME/.local/bin/mise
if [ ! -e "$MISE" ]; then
    echo -e "${RED}installing mise...${NC}"
    curl https://mise.run | sh
fi

tools=(
  "node"
  "python"
  "neovim"
  "fd"
  "fzf"
  "ripgrep"
)


for tool in "${tools[@]}"; do
    echo -e "--------------------------------------------------"
    echo -e "${YELLOW}[mise] installing: ${tool}...${NC}"
    if $MISE use -g "$tool"; then
        echo -e "${GREEN}installed: ${tool}${NC}"
    else
        echo -e "${RED}failed to install: ${tool}${NC}"
	exit 1
    fi
done

$MISE activate --shims
$HOME/.local/share/mise/shims/pip install pynvim
export PATH="$PATH:$HOME/.local/share/mise/shims" # make nvim command available
nvim --headless -c "Lazy load wilder.nvim" -c "UpdateRemotePlugins" -c "quit"

# install tmux and tmux plugins
if ! command -v tmux; then
  echo -e "${GREEN}tmux not available, installing tmux...${NC}"
  echo -e "${YELLOW}install tmux with system package manager to avoid compilation, note newer version tmux if preferred.${NC}"
  MISE_JOBS=16 $MISE install tmux
  $MISE use -g tmux
  echo -e "${GREEN}tmux installation done${NC}"
fi


TPM_PATH="$HOME/.tmux/plugins/tpm"
if [[ -f "$TPM_PATH/bin/install_plugins" ]] && command -v tmux; then
  echo "Installing tmux plugins..."
  $TPM_PATH/bin/install_plugins
  echo "Tmux plugins installation process triggered."
  echo "Note: You might need to source your ~/.tmux.conf or restart tmux for changes to take effect."
else
  echo -e "${RED}[WARNING]: skipping tmux installation${NC}"
fi

echo "done."
