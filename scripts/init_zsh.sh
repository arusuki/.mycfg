export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="robbyrussell"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting z history-substring-search)

ZSH_CUSTOM=$HOME/zsh_custom

DISABLE_AUTO_UPDATE="true"

source $ZSH/oh-my-zsh.sh

# at $HOME, execute:
#     git clone --bare https://github.com/arusuki/.mycfg.git .mycfg
#     alias config='/usr/bin/git --git-dir=$HOME/.mycfg/ --work-tree=$HOME'
#     config config --local status.showUntrackedFiles no
#     config checkout
#     config submodule update --init
#
#  to initialize tmux tpm plugins, type:
#     <C-D>I

alias config='/usr/bin/git --git-dir=$HOME/.mycfg/ --work-tree=$HOME'
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down

