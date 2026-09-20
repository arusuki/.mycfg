# Must work in Bash and Zsh.
_mycfg_prepend_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

_mycfg_prepend_path "$HOME/.local/bin"
case "$(uname -s)" in
  Linux)
    export AQUA_ROOT_DIR="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}"
    export MYCFG_AQUA_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/mycfg/aqua.yaml"
    _mycfg_aqua_config="$MYCFG_AQUA_CONFIG"
    [ -f "$_mycfg_aqua_config" ] || _mycfg_aqua_config="$HOME/scripts/linux/aqua.yaml"
    # Replace stale entries inherited from older shells.
    _mycfg_aqua_remaining=${AQUA_GLOBAL_CONFIG:-}
    AQUA_GLOBAL_CONFIG=$_mycfg_aqua_config
    while [ -n "$_mycfg_aqua_remaining" ]; do
      _mycfg_aqua_entry=${_mycfg_aqua_remaining%%:*}
      case "$_mycfg_aqua_remaining" in
        *:*) _mycfg_aqua_remaining=${_mycfg_aqua_remaining#*:} ;;
        *) _mycfg_aqua_remaining= ;;
      esac
      case "$_mycfg_aqua_entry" in
        ''|"$HOME/scripts/linux/aqua.yaml"|"$MYCFG_AQUA_CONFIG") ;;
        *) AQUA_GLOBAL_CONFIG="$AQUA_GLOBAL_CONFIG:$_mycfg_aqua_entry" ;;
      esac
    done
    export AQUA_GLOBAL_CONFIG
    unset _mycfg_aqua_config _mycfg_aqua_remaining _mycfg_aqua_entry
    case ":${AQUA_POLICY_CONFIG:-}:" in
      *":$HOME/scripts/linux/aqua-policy.yaml:"*) ;;
      *) export AQUA_POLICY_CONFIG="$HOME/scripts/linux/aqua-policy.yaml${AQUA_POLICY_CONFIG:+:$AQUA_POLICY_CONFIG}" ;;
    esac
    # Loading this config before installation would enable lazy installs of uv.
    if [ -x "$AQUA_ROOT_DIR/bin/uv" ]; then
      case ":$AQUA_GLOBAL_CONFIG:" in
        *":$HOME/scripts/linux/uv.yaml:"*) ;;
        *) export AQUA_GLOBAL_CONFIG="$AQUA_GLOBAL_CONFIG:$HOME/scripts/linux/uv.yaml" ;;
      esac
    fi
    export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-${XDG_DATA_HOME:-$HOME/.local/share}/npm-global}"
    _mycfg_prepend_path "$NPM_CONFIG_PREFIX/bin"
    _mycfg_prepend_path "$AQUA_ROOT_DIR/bin"
    ;;
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      eval "$(brew shellenv)"
    elif [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    ;;
esac
unset -f _mycfg_prepend_path
