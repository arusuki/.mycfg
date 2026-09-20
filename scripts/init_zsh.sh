alias config='git --git-dir="$HOME/.mycfg/" --work-tree="$HOME"'

# Submodules may have been removed by uninstall.sh.
[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ] || return 0

export ZSH=$HOME/.oh-my-zsh
source "$HOME/scripts/env.sh"

ZSH_THEME="robbyrussell"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting z history-substring-search)

ZSH_CUSTOM=$HOME/zsh_custom

DISABLE_AUTO_UPDATE="true"

source $ZSH/oh-my-zsh.sh

bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down

# Send cwd to Neovim terminal via OSC 7
autoload -Uz add-zsh-hook

_nvim_osc7() {
  [[ -n "$NVIM" ]] || return
  printf '\033]7;file://%s\033\\' "$PWD"
}

add-zsh-hook precmd _nvim_osc7
