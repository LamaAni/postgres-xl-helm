#!/bin/bash

#=================================================================================================
# REUSABLE FUNCTIONS
#-------------------------------------------------------------------------------------------------
function json_array() {
  echo -n '['
  while [ $# -gt 0 ]; do
    x=${1//\\/\\\\}
    echo -n \"${x//\"/\\\"}\"
    [ $# -gt 1 ] && echo -n ', '
    shift
  done
  echo ']'
}

function replace_with_env() {
  # replace any {{ENV_NAME}} with its respective env value.
  value="$1"

  # the regular expression matches {{ [SOME NAME] }}
  re='(.*)\{\{\s*(\w+)\s*\}\}(.*)'

  # search for all replacements.
  while [[ "$value" =~ $re ]]; do
    env_name=${BASH_REMATCH[2]}
    value="${BASH_REMATCH[1]}${!env_name}${BASH_REMATCH[3]}"
  done

  echo "$value"
}
#=================================================================================================
