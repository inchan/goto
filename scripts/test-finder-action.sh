#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"

temp_root="$(mktemp -d)"
workflow_path="$temp_root/Goto in Terminal.workflow"
selected_dir="$temp_root/프로젝트 한글 test"
mkdir -p -- "$selected_dir"

GOTO_WORKFLOW_LAUNCH_ARGS="--dry-run" \
  "$SCRIPT_DIR/render-finder-workflow.sh" "$workflow_path" >/dev/null

pbs_output="$(
  /System/Library/CoreServices/pbs -read_bundle "$workflow_path" 2>&1
)"
printf '%s\n' "$pbs_output" | grep -F 'runWorkflowAsService' >/dev/null
printf '%s\n' "$pbs_output" | grep -F 'public.folder' >/dev/null

automator_output="$(
  automator -i "$selected_dir" "$workflow_path" 2>"$temp_root/automator.err"
)"
returned_path="$(
  printf '%s\n' "$automator_output" |
    grep '"' |
    sed -n 's/^[[:space:]]*"//; s/"$//; p' |
    head -n 1
)"

if [[ -z "$returned_path" ]]; then
  printf 'Finder workflow returned no path.\n' >&2
  sed -n '1,120p' "$temp_root/automator.err" >&2 || true
  exit 1
fi

[[ -d "$returned_path" ]]
expected_stat="$(stat -f '%d:%i' "$selected_dir")"
actual_stat="$(stat -f '%d:%i' "$returned_path")"
[[ "$expected_stat" == "$actual_stat" ]]

printf 'Finder workflow test passed for %s\n' "$selected_dir"
