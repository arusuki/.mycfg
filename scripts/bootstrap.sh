#!/usr/bin/env bash
# Linux prerequisites: git, curl, bash, tar, sha256sum, C/C++ compiler, make, zsh.
# macOS prerequisites: Xcode Command Line Tools (xcode-select --install).
set -euo pipefail

os=$(uname -s)
case "$os" in
  Linux|Darwin) ;;
  *) printf 'Unsupported OS: %s\n' "$os" >&2; exit 1 ;;
esac

uv_option=${1:-ask}
if [ "$#" -gt 1 ]; then
  echo 'Usage: bootstrap.sh [--with-uv|--without-uv]' >&2
  exit 1
fi
case "$uv_option" in
  --with-uv|--without-uv) ;;
  --help|-h)
    echo 'Usage: bootstrap.sh [--with-uv|--without-uv]'
    exit 0
    ;;
  ask)
    uv_option=--without-uv
    if [ -t 0 ]; then
      while true; do
        uv_answer=
        read -r -p '是否安装可选的 uv（Python 工具）？[y/N] ' uv_answer || break
        case "$uv_answer" in
          y|Y|[yY][eE][sS]) uv_option=--with-uv; break ;;
          ''|n|N|[nN][oO]) break ;;
          *) echo '请输入 y 或 n。' ;;
        esac
      done
    else
      echo 'Non-interactive input: skipping optional uv (use --with-uv to install).'
    fi
    ;;
  *) echo 'Usage: bootstrap.sh [--with-uv|--without-uv]' >&2; exit 1 ;;
esac

# Standalone preflight: bootstrap may run before checkout.
if [ "$os" = Linux ]; then
  libc=$(getconf GNU_LIBC_VERSION 2>/dev/null || true)
  if [[ ! "$libc" =~ ^glibc\ ([0-9]+)\.([0-9]+)$ ]]; then
    echo 'Cannot detect glibc; Linux bootstrap requires glibc >= 2.28.' >&2
    exit 1
  fi
  if [ "${BASH_REMATCH[1]}" -lt 2 ] || { [ "${BASH_REMATCH[1]}" -eq 2 ] && [ "${BASH_REMATCH[2]}" -lt 28 ]; }; then
    printf 'Unsupported %s: Linux bootstrap requires glibc >= 2.28.\n' "$libc" >&2
    exit 1
  fi
fi

cd "$HOME"
config() {
  git --git-dir="$HOME/.mycfg/" --work-tree="$HOME" "$@"
}

if [ ! -d "$HOME/.mycfg" ]; then
  git clone --bare https://github.com/arusuki/.mycfg.git "$HOME/.mycfg"
  config checkout
fi
config config --local status.showUntrackedFiles no
config submodule update --init --recursive -- \
  .oh-my-zsh .tmux/plugins/tpm \
  zsh_custom/plugins/zsh-autosuggestions zsh_custom/plugins/zsh-syntax-highlighting

bash "$HOME/scripts/install_packages.sh" "$uv_option"
source "$HOME/scripts/env.sh"

TPM_PATH="$HOME/.tmux/plugins/tpm"
if [ -f "$TPM_PATH/bin/install_plugins" ] && command -v tmux >/dev/null 2>&1; then
  echo 'Installing tmux plugins...'
  "$TPM_PATH/bin/install_plugins"
else
  echo 'Skipping tmux plugins: tmux or TPM is unavailable.'
fi

source "$HOME/scripts/lib/zshrc.sh"
mycfg_zshrc add

echo 'Done. Open a new Zsh session to load the package manager environment.'
