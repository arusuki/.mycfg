export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="jonathan"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting z)

ZSH_CUSTOM=$HOME/zsh_custom

source $ZSH/oh-my-zsh.sh

# at $HOME, execute:
#     config config status.showUntrackedFiles no
#     config checkout
#     config submodule update --init

alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

