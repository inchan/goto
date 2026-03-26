# Source this file to make `goto` jump in the current zsh session.

typeset -g _GOTO_ZSH_SOURCE="${${(%):-%N}:A}"

_goto_repo_root() {
  emulate -L zsh

  local shell_dir
  shell_dir="${_GOTO_ZSH_SOURCE:h}"

  builtin cd -P -- "$shell_dir/.." >/dev/null 2>&1 && pwd -P
}

_goto_invoke() {
  emulate -L zsh

  local repo_root cli_path

  repo_root="$(_goto_repo_root)" || {
    print -u2 'goto: unable to resolve repository root'
    return 1
  }

  cli_path="$repo_root/bin/goto.js"
  if [[ ! -f "$cli_path" ]]; then
    print -u2 "goto: expected CLI at $cli_path"
    return 1
  fi

  command node "$cli_path" "$@"
}

goto() {
  emulate -L zsh

  local target exit_code

  if (( $# == 0 )); then
    target="$(_goto_invoke)"
    exit_code=$?

    if (( exit_code != 0 )); then
      return $exit_code
    fi

    [[ -n "$target" ]] || return 0
    builtin cd -- "$target"
    return $?
  fi

  _goto_invoke "$@"
}
