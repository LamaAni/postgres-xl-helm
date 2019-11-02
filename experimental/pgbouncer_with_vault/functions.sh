#!/usr/bin/env bash

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
  str="$1"

  while [[ $str =~ ('{{'([[:alnum:]_]+)'}}') ]]; do
      str=${str//${BASH_REMATCH[1]}/${!BASH_REMATCH[2]}}
  done

  echo "$str"
}
#=================================================================================================
