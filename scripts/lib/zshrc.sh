# Only edit standalone source lines for this configuration.
mycfg_zshrc_filter() {
  awk -v action="$1" '
    function is_init(line, quote) {
      sub(/^[ \t]+/, "", line)
      sub(/[ \t]+#.*/, "", line)
      sub(/[ \t]+$/, "", line)
      sub(/;$/, "", line)
      sub(/[ \t]+$/, "", line)
      if (line !~ /^(source|\.)[ \t]+/) return 0
      sub(/^(source|\.)[ \t]+/, "", line)
      quote = substr(line, 1, 1)
      if ((quote == "\042" || quote == "\047") && substr(line, length(line), 1) == quote)
        line = substr(line, 2, length(line) - 2)
      return line == "$HOME/scripts/init_zsh.sh" ||
        line == "${HOME}/scripts/init_zsh.sh" ||
        line == "~/scripts/init_zsh.sh" ||
        line == ENVIRON["HOME"] "/scripts/init_zsh.sh"
    }
    is_init($0) { found = 1; if (action == "remove") next }
    { if (action == "remove") print }
    END { if (action == "check" && !found) exit 1 }
  ' "$2"
}

mycfg_zshrc() {
  local action=$1 zshrc="${ZDOTDIR:-$HOME}/.zshrc" temporary
  case "$action" in
    add)
      if [ -f "$zshrc" ] && mycfg_zshrc_filter check "$zshrc"; then
        return 0
      fi
      mkdir -p -- "$(dirname -- "$zshrc")" || return
      if [ -s "$zshrc" ] && [ -n "$(tail -c 1 "$zshrc")" ]; then
        printf '\n' >> "$zshrc" || return
      fi
      printf 'source "$HOME/scripts/init_zsh.sh"\n' >> "$zshrc"
      ;;
    remove)
      [ -f "$zshrc" ] || return 0
      mycfg_zshrc_filter check "$zshrc" || return 0
      temporary=$(mktemp) || return
      if mycfg_zshrc_filter remove "$zshrc" > "$temporary"; then
        # Write through symlinks and preserve the existing file permissions.
        cat "$temporary" > "$zshrc" || { rm -f -- "$temporary"; return 1; }
      else
        rm -f -- "$temporary"
        return 1
      fi
      rm -f -- "$temporary"
      ;;
    *) return 1 ;;
  esac
}
