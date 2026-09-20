# Replace the alias too when reloading an existing shell.
unalias config 2>/dev/null || true
function config() {
  local -a config_git_args=(--git-dir="$HOME/.mycfg/" --work-tree="$HOME")
  local config_result=0 submodule_result=0

  command git "${config_git_args[@]}" "$@" || config_result=$?
  if [[ "${1-}" == pull ]]; then
    # Always reconcile submodules, even after a failed pull, from the worktree root.
    command git "${config_git_args[@]}" -C "$HOME" submodule sync --recursive || submodule_result=$?
    command git "${config_git_args[@]}" -C "$HOME" submodule update --init --recursive || submodule_result=$?
    if (( config_result == 0 )); then
      config_result=$submodule_result
    fi
  fi
  return "$config_result"
}

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
