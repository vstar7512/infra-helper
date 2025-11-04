#!/usr/bin/env bash

set +o history # temporarily turn off history

# If sourced, remember caller's shell options to restore later
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  __TFVARS_PREV_OPTS="$(set +o)"
fi

# Use strict mode only inside the script block
set -euo pipefail

ENV_FILE_PATH=$1

load_env() {
  set -a
  # shellcheck disable=SC1091
  source $ENV_FILE_PATH
  set +a
}

get_var_names() {
  # extract names even if lines have 'export', ignore blanks/comments, handle CRLF
  sed -e 's/\r$//' $ENV_FILE_PATH \
  | grep -E '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=' \
  | sed -E 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=.*/\2/' \
  | sort -u
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Executed: print export lines you can source
  load_env
  while read -r name; do
    [[ -v $name ]] || continue
    printf 'export TF_VAR_%s=%q\n' "$name" "${!name}"
  done < <(get_var_names)
else
  # Sourced: export into current shell
  load_env
  while read -r name; do
    [[ -v $name ]] || continue
    export "TF_VAR_${name}=${!name}"
    echo $name
  done < <(get_var_names)

  # Restore caller’s shell options so -e/-u don’t persist
  eval "$__TFVARS_PREV_OPTS"
  unset __TFVARS_PREV_OPTS
fi

set -o history # turn it back on
