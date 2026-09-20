#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'Usage: uninstall.sh [--dry-run] [--keep-uv] [--yes]'
  echo 'Interactive tree: checked items are removed; checked managers force all children on.'
  echo '--yes skips the menu and removes bootstrap packages/plugins, keeping managers.'
  echo '--keep-uv leaves uv unchecked by default; selecting its manager overrides this.'
}

dry_run=0
keep_uv=0
skip_menu=0
for option in "$@"; do
  case "$option" in
    --dry-run) dry_run=1 ;;
    --keep-uv) keep_uv=1 ;;
    --yes) skip_menu=1 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done
os=$(uname -s)
case "$os" in
  Linux|Darwin) ;;
  *) printf 'Unsupported OS: %s\n' "$os" >&2; exit 1 ;;
esac
if [ "$skip_menu" -eq 0 ] && { [ ! -t 0 ] || [ ! -t 1 ]; }; then
  if [ "$dry_run" -eq 1 ]; then
    skip_menu=1
  else
    echo '交互菜单需要终端；自动执行请显式使用 --yes，或用 --dry-run 预览。' >&2
    exit 1
  fi
fi
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/env.sh"
source "$script_dir/lib/zshrc.sh"
source "$script_dir/lib/uninstall-menu.sh"
cd "$HOME"
failed=0

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  if [ "$dry_run" -eq 0 ]; then "$@"; fi
}
config() {
  git --git-dir="$HOME/.mycfg/" --work-tree="$HOME" "$@"
}
contains_line() {
  printf '%s\n' "$1" | grep -Fx -- "$2" >/dev/null
}

export AQUA_ROOT_DIR="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}"
aqua_bin=$(command -v aqua || true)
if [ -z "$aqua_bin" ] && [ -x "$AQUA_ROOT_DIR/bin/aqua" ]; then
  aqua_bin="$AQUA_ROOT_DIR/bin/aqua"
fi
aqua_root_index=-1
if [ -n "$aqua_bin" ]; then
  aqua_root=$("$aqua_bin" root-dir)
  menu_add "aqua — 管理器及整个数据目录：$aqua_root" aqua_root "$aqua_root" -1 0
  aqua_root_index=$menu_last
  defaults=$(sed -nE 's/^[[:space:]]*-[[:space:]]*name:[[:space:]]*([^@[:space:]]+)@[^[:space:]]+.*/\1/p' "$script_dir/linux/aqua.yaml" "$script_dir/linux/uv.yaml")
  installed=$("$aqua_bin" list -a -installed)
  seen=''
  while read -r package version registry extra; do
    [ -n "$package" ] || continue
    registry=${registry:-standard}
    package_id="$registry,$package"
    contains_line "$seen" "$package_id" && continue
    seen="$seen
$package_id"
    checked=0
    if [ "$os" = Linux ] && contains_line "$defaults" "$package"; then
      case "$registry" in standard|mycfg-compat) checked=1 ;; esac
    fi
    if [ "$keep_uv" -eq 1 ] && [ "$package" = astral-sh/uv ]; then checked=0; fi
    menu_add "$package [$registry]（所有已安装版本）" aqua_package "$package_id" "$aqua_root_index" "$checked"
  done <<< "$installed"
fi

brew_bin=$(command -v brew || true)
if [ -z "$brew_bin" ]; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [ -x "$candidate" ]; then brew_bin=$candidate; break; fi
  done
fi
brew_root_index=-1
if [ -n "$brew_bin" ]; then
  export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_AUTOREMOVE=1
  brew_prefix=$("$brew_bin" --prefix)
  menu_add "Homebrew — 管理器及全部软件：$brew_prefix" brew_root "$brew_prefix" -1 0
  brew_root_index=$menu_last
  export MYCFG_WITH_UV=$((1 - keep_uv))
  defaults=$("$brew_bin" bundle list --file="$script_dir/macos/Brewfile" --formula)
  for kind in formula cask; do
    installed=$("$brew_bin" list "--$kind" -1)
    while IFS= read -r package; do
      [ -n "$package" ] || continue
      checked=0
      if [ "$os" = Darwin ] && [ "$kind" = formula ] && contains_line "$defaults" "$package"; then checked=1; fi
      menu_add "$package [$kind]" "brew_$kind" "$package" "$brew_root_index" "$checked"
    done <<< "$installed"
  done
fi

# Match TPM's default config selection without starting a tmux server.
tmux_config="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
[ -f "$tmux_config" ] || tmux_config="$HOME/.tmux.conf"
plugin_root=${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}
case "$plugin_root" in
  '~/'*) plugin_root="$HOME/${plugin_root#\~/}" ;;
  '$HOME/'*) plugin_root="$HOME/${plugin_root#\$HOME/}" ;;
esac
menu_add 'tmux 插件（全选）' group '' -1 0
plugin_root_index=$menu_last
if [ -f "$tmux_config" ]; then
  plugin_names=$(awk '/^[ \t]*set(-option)? +-g +@plugin / { gsub(/[\047\042]/, "", $4); print $4 }' "$tmux_config")
  while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    plugin=${plugin%%#*}; plugin=${plugin##*/}; plugin=${plugin%.git}
    case "$plugin" in ''|.|..|tpm) continue ;; esac
    [ -d "$plugin_root/$plugin" ] || continue
    menu_add "$plugin" plugin "$plugin_root/$plugin" "$plugin_root_index" 1
  done <<< "$plugin_names"
fi
menu_add 'Git 子模块（全选，保留 Git 数据）' group '' -1 0
module_root_index=$menu_last
modules=(zsh_custom/plugins/zsh-syntax-highlighting zsh_custom/plugins/zsh-autosuggestions .tmux/plugins/tpm .oh-my-zsh)
if [ -d "$HOME/.mycfg" ]; then
  for module in "${modules[@]}"; do
    [ -e "$HOME/$module/.git" ] || continue
    menu_add "$module" module "$module" "$module_root_index" 1
  done
fi

if [ "$skip_menu" -eq 0 ] && ! menu_show; then
  echo '已取消，未执行卸载。'
  exit 0
fi
printf '将卸载以下项目：\n'
for ((index=0; index<menu_count; index++)); do
  if menu_selected "$index" && [ "${menu_types[index]}" != group ]; then
    printf '  [x] %s\n' "${menu_labels[index]}"
  fi
done
printf '  自动移除 %s/.zshrc 中 init_zsh.sh 的加载行。\n' "${ZDOTDIR:-$HOME}"
if [ "$skip_menu" -eq 0 ] && [ "$dry_run" -eq 0 ]; then
  answer=''
  read -r -p '执行以上卸载？[y/N] ' answer || true
  case "$answer" in y|Y|yes|YES) ;; *) echo '已取消，未执行卸载。'; exit 0 ;; esac
fi

remove_plugin() {
  local path=$1 changes
  if [ -L "$plugin_root" ] || [ -L "$path" ] || [ ! -e "$path/.git" ]; then
    printf 'Keeping unrecognized plugin directory: %s\n' "$path" >&2
    return 1
  fi
  if ! changes=$(git -C "$path" status --porcelain --untracked-files=all) || [ -n "$changes" ]; then
    printf 'Keeping modified plugin: %s\n' "$path" >&2
    return 1
  fi
  rm -rf -- "$path"
}
remove_aqua_root() {
  local path=$1 physical protected
  [ -d "$path" ] || return 0
  # Resolve symlinked ancestors before checking for overly broad custom roots.
  physical=$(cd -- "$path" && pwd -P) || return
  for protected in / /usr /usr/local /opt /home /var /tmp "$HOME" "$script_dir" "$HOME/.mycfg" \
    "$HOME/.local" "$HOME/.local/share" "$HOME/.config" "${XDG_DATA_HOME:-$HOME/.local/share}"; do
    case "$protected/" in
      "$physical/"*) printf 'Refusing unsafe aqua root: %s\n' "$path" >&2; return 1 ;;
    esac
  done
  if [ -L "$path" ] || [ ! -x "$path/bin/aqua" ]; then
    echo 'Cannot remove aqua root: expected an installer-managed bin/aqua; external installations must be removed with their own manager.' >&2
    return 1
  fi
  rm -rf -- "$physical"
}
remove_brew_root() (
  local prefix=$1 installer
  installer=$(mktemp) || exit 1
  trap 'rm -f -- "$installer"' EXIT
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh -o "$installer" || exit 1
  /bin/bash "$installer" --force --path="$prefix"
)

# Finish Git and shell work before removing tools that may provide these commands.
run mycfg_zshrc remove || failed=1
for ((index=0; index<menu_count; index++)); do
  menu_selected "$index" || continue
  case "${menu_types[index]}" in
    plugin) run remove_plugin "${menu_values[index]}" || failed=1 ;;
    module) run config submodule deinit -- "${menu_values[index]}" || failed=1 ;;
  esac
done
if [ "$aqua_root_index" -ge 0 ]; then
  if menu_selected "$aqua_root_index"; then
    run remove_aqua_root "$aqua_root" || failed=1
  else
    packages=()
    for ((index=0; index<menu_count; index++)); do
      if [ "${menu_types[index]}" = aqua_package ] && menu_selected "$index"; then packages+=("${menu_values[index]}"); fi
    done
    if [ "${#packages[@]}" -gt 0 ]; then run "$aqua_bin" remove --mode pl "${packages[@]}" || failed=1; fi
  fi
fi
if [ "$brew_root_index" -ge 0 ]; then
  brew_failed=0
  for kind in cask formula; do
    # Remove casks first: their apps may live outside the prefix.
    if [ "$kind" = formula ] && menu_selected "$brew_root_index"; then continue; fi
    packages=()
    for ((index=0; index<menu_count; index++)); do
      if [ "${menu_types[index]}" = "brew_$kind" ] && menu_selected "$index"; then packages+=("${menu_values[index]}"); fi
    done
    if [ "${#packages[@]}" -gt 0 ]; then
      run "$brew_bin" uninstall "--$kind" "${packages[@]}" || brew_failed=1
    fi
  done
  if menu_selected "$brew_root_index" && [ "$brew_failed" -eq 0 ]; then
    run remove_brew_root "$brew_prefix" || brew_failed=1
  fi
  [ "$brew_failed" -eq 0 ] || failed=1
fi
if [ "$failed" -ne 0 ]; then
  echo 'Uninstall incomplete. Resolve the errors above and rerun.' >&2
  exit 1
fi
if [ "$dry_run" -eq 1 ]; then
  echo 'Dry run complete. No uninstall commands were executed.'
else
  echo 'Done. Selected items and the Zsh source line were removed. Open a new shell.'
fi
