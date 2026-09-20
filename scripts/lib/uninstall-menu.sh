# Bash 3.2; parent selection preserves each child's previous state.
menu_labels=() menu_types=() menu_values=() menu_parents=() menu_checks=()
menu_count=0

menu_add() {
  menu_labels[menu_count]=$1
  menu_types[menu_count]=$2
  menu_values[menu_count]=$3
  menu_parents[menu_count]=$4
  menu_checks[menu_count]=$5
  menu_last=$menu_count
  menu_count=$((menu_count + 1))
}

menu_selected() {
  local index=$1
  while [ "$index" -ge 0 ]; do
    [ "${menu_checks[index]}" -eq 0 ] || return 0
    index=${menu_parents[index]}
  done
  return 1
}

menu_locked() {
  local parent=${menu_parents[$1]}
  [ "$parent" -ge 0 ] && menu_selected "$parent"
}

menu_toggle() {
  menu_locked "$1" && return 0
  menu_checks[$1]=$((1 - menu_checks[$1]))
}

menu_restore() {
  printf '\033[?7h\033[?25h\033[?1049l'
}

menu_show() {
  local cursor=0 offset=0 rows=24 columns=80 height index mark indent locked key rest
  trap menu_restore EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  printf '\033[?1049h\033[?25l\033[?7l'
  while true; do
    read -r rows columns < <(stty size 2>/dev/null) || { rows=24; columns=80; }
    height=$((rows - 7))
    [ "$height" -ge 1 ] || height=1
    [ "$cursor" -ge "$offset" ] || offset=$cursor
    [ "$cursor" -lt "$((offset + height))" ] || offset=$((cursor - height + 1))
    printf '\033[H\033[J'
    printf '选择要卸载的项目（[x] 卸载，[ ] 保留）\n'
    printf '↑/↓ 或 j/k 移动 · 空格勾选 · Enter 继续 · q 取消\n'
    printf '勾选根节点：所属软件全部勾选并锁定；取消根节点恢复单项选择。\n\n'
    for ((index=offset; index<menu_count && index<offset+height; index++)); do
      mark=' '; indent=''; locked=''
      menu_selected "$index" && mark=x
      if [ "${menu_parents[index]}" -ge 0 ]; then indent='  └─ '; fi
      menu_locked "$index" && locked=' (由根节点选中)'
      [ "$index" -ne "$cursor" ] || printf '\033[7m'
      # Strip control characters from labels supplied by external package tools.
      printf '[%s] %s%s%s\033[0m\n' "$mark" "$indent" "${menu_labels[index]//[[:cntrl:]]/?}" "$locked"
    done
    printf '\n%d/%d · 执行时自动移除 .zshrc 中本配置的加载行。\n' "$((cursor+1))" "$menu_count"
    key=''
    IFS= read -rsn1 key || { menu_restore; trap - EXIT INT TERM; return 1; }
    case "$key" in
      $'\033')
        rest=''
        IFS= read -rsn2 -t 1 rest || true
        case "$rest" in '[A') key=k ;; '[B') key=j ;; *) key='' ;; esac
        # An unrecognized escape sequence must not act like Enter.
        [ -n "$key" ] || continue
        ;;
    esac
    case "$key" in
      k) cursor=$(((cursor + menu_count - 1) % menu_count)) ;;
      j) cursor=$(((cursor + 1) % menu_count)) ;;
      ' ') menu_toggle "$cursor" ;;
      '') break ;;
      q|Q) menu_restore; trap - EXIT INT TERM; return 1 ;;
    esac
  done
  menu_restore
  trap - EXIT INT TERM
}
