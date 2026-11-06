# Source from an interactive Zsh; init_zsh.sh loads this after Oh My Zsh.
[[ -n ${ZSH_VERSION-} ]] || return 0
[[ -o interactive ]] || return 0

# Reuse Oh My Zsh's completion setup. For standalone use, initialize once
# without writing a second completion dump or trusting insecure directories.
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit -i -D
fi

# Enter: native spelling prompts for lines with arguments; the widget below
# corrects a single bare command immediately before accepting the line.
# HASH_LIST_ALL lets correction see commands not yet used in this session.
setopt correct correct_all hash_list_all
SPROMPT='zsh: correct "%R" to "%r"? [y=yes, n=no, a=abort, e=edit] '

# Tab: try normal completion first, then correction of the whole word, then
# correction with completion. Subcommands/options need a completion function.
zstyle ':completion:*' completer _complete _ignored _correct _approximate
zstyle ':completion:*:correct:*' max-errors 2 not-numeric
zstyle ':completion:*:approximate:*' max-errors 2 not-numeric
zstyle ':completion:*:corrections' format '%F{yellow}%d (errors: %e)%f'

# Space uses contextual native correction, but never opens a completion menu
# or expands a valid prefix. Only one unambiguous correction may be inserted.
zstyle ':completion:mycfg-space:*' menu no
zstyle ':completion:mycfg-space:*' matcher-list ''
zstyle ':completion:mycfg-space:*' insert-tab false
zstyle ':completion:mycfg-space:*' show-completer false

_mycfg_space_complete() {
  local curcontext='mycfg-space:::'
  _main_complete _complete _correct
  compstate[list]=''
  compstate[insert]=''
  if [[ $_lastcomp[completer] == correct && $compstate[nmatches] == 1 ]]; then
    compstate[insert]=unambiguous
  fi
  return 0
}

_mycfg_correct_space() {
  emulate -L zsh
  local before=$BUFFER word
  local -a line_words
  # Limit automatic edits to simple, unquoted lines at the end of the buffer.
  # Quoting, expansion, compound commands, and editing mid-line stay literal.
  if [[ ${MYCFG_SPACE_CORRECTION:-on} == on && -z $RBUFFER &&
        -n $LBUFFER && $LBUFFER != *[[:space:]] &&
        $LBUFFER != *[^[:alnum:]_./~\ -]* ]]; then
    line_words=(${(z)LBUFFER})
    for word in "${line_words[@]}"; do
      if [[ $word == nocorrect || ${aliases[$word]-} == nocorrect\ * ]]; then
        zle .self-insert
        return
      fi
    done
    zle _mycfg-space-complete
  fi
  # Completion can supply its own trailing space; do not insert a second one.
  if [[ $BUFFER == "$before" || $LBUFFER != *' ' ]]; then
    zle .self-insert
  fi
}

zle -C _mycfg-space-complete .complete-word _mycfg_space_complete
zle -N mycfg-correct-space _mycfg_correct_space
bindkey -M emacs ' ' mycfg-correct-space
bindkey -M viins ' ' mycfg-correct-space

_mycfg_accept_line() {
  local correction_enabled=$options[correct]
  emulate -L zsh
  local MATCH
  local -a match mbegin mend
  # Only one bare command, with optional surrounding horizontal whitespace.
  # Arguments, quotes, expansions, redirections and compound lines keep the
  # normal confirmation path. Move to the word even if the cursor is elsewhere.
  if [[ $correction_enabled == on &&
        $BUFFER =~ '^([[:blank:]]*)([[:alnum:]_./~-]+)[[:blank:]]*$' ]]; then
    CURSOR=$(( ${#match[1]} + ${#match[2]} ))
    zle .spell-word
  fi
  zle accept-line
}

zle -N mycfg-accept-line _mycfg_accept_line
bindkey -M emacs '^M' mycfg-accept-line
bindkey -M emacs '^J' mycfg-accept-line
bindkey -M viins '^M' mycfg-accept-line
bindkey -M viins '^J' mycfg-accept-line
bindkey -M vicmd '^M' mycfg-accept-line
bindkey -M vicmd '^J' mycfg-accept-line

# Keep aliases and CORRECT_IGNORE{,_FILE}; these native patterns control Enter.
# `nocorrect command ...` bypasses both Enter-time and Space-time correction.
