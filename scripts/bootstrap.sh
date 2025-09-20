#!/bin/bash
set -e
current=$(pwd)
cd $HOME

cleanup() {
    if [ -n "$current" ]; then
        cd "$current"
    fi
}

trap cleanup EXIT

# clone bare repo
git clone --bare https://github.com/arusuki/.mycfg.git .mycfg
alias config='/usr/bin/git --git-dir=$HOME/.mycfg/ --work-tree=$HOME'
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
