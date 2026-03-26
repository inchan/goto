# Source this file to make `goto` jump in the current bash session.

_goto_repo_root() {
  local source_path shell_dir

  source_path="${BASH_SOURCE[0]}"
  shell_dir="$(
    builtin cd -P -- "$(dirname -- "$source_path")" >/dev/null 2>&1 && pwd -P
  )" || return 1

  builtin cd -P -- "$shell_dir/.." >/dev/null 2>&1 && pwd -P
}

_goto_invoke() {
  local repo_root cli_path

  repo_root="$(_goto_repo_root)" || {
    printf 'goto: unable to resolve repository root\n' >&2
    return 1
  }

  cli_path="$repo_root/bin/goto.js"
  if [[ ! -f "$cli_path" ]]; then
    printf 'goto: expected CLI at %s\n' "$cli_path" >&2
    return 1
  fi

  command node "$cli_path" "$@"
}

goto() {
  local target status

  if (( $# == 0 )); then
    target="$(_goto_invoke)"
    status=$?

    if (( status != 0 )); then
      return "$status"
    fi

    [[ -n "$target" ]] || return 0
    builtin cd -- "$target"
    return $?
  fi

  _goto_invoke "$@"
}
