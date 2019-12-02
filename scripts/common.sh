#!/usr/bin/env bash

# black="\e[0;30m"
# red="\e[0;31m"
# green="\e[0;32m"
# yellow="\e[0;33m"
# blue="\e[0;34m"
# purple="\e[0;35m"
# cyan="\e[0;36m"
# white="\e[0;37m"
# orange="\e[0;91m"

# Methods and functions to be used in all other scripts.
: ${LOGGING_SHOW_COLORS:="true"}
: ${LOGGING_INFO_PREFEX_COLOR:="\e[0;32m"}
: ${LOGGING_INFO_PREFEX:=":INFO"}
: ${LOGGING_ERROR_PREFEX_COLOR:="\e[0;31m"}
: ${LOGGING_ERROR_PREFEX:=":ERROR"}
: ${LOGGING_WARNING_PREFEX_COLOR:="\e[0;33m"}
: ${LOGGING_WARNING_PREFEX:=":WARNING"}
: ${LOGGING_ARCHIVE_PREFEX_COLOR:="\e[0;34m"}
: ${LOGGING_ARCHIVE_PREFEX:=":INFO"}
: ${LOGGING_SCRIPT_PREFEX:=":INFO"}
: ${LOGGING_SCRIPT_PREFEX_COLOR:="\e[0;36m"}
: ${LOGGING_SCRIPT_TEXT_COLOR:="\e[0;35m"}

# TODO: Apply common format for stackdriver.
logging_core_print() {
  local log_type="$1"
  local reset_color="\e[0m"
  # remove the first argument.
  shift

  local log_type_prefex_env_name="LOGGING_${log_type}_PREFEX"
  log_type_prefex="${!log_type_prefex_env_name}"

  if [ "$LOGGING_SHOW_COLORS" != "true" ]; then
    echo "$LOGGING_PREFIX$log_type_prefex " "$@"
  else
    local log_prefex_color_env_name="LOGGING_${log_type}_PREFEX_COLOR"
    local log_text_color_env_name="LOGGING_${log_type}_TEXT_COLOR"
    log_prefex_color="${!log_prefex_color_env_name}"
    log_text_color="${!log_text_color_env_name}"

    if [ -z "$log_text_color" ]; then log_text_color="$reset_color"; fi

    echo -e "$log_prefex_color$LOGGING_PREFIX$log_type_prefex$log_text_color" "$@" "$reset_color"
  fi
}

# log a line with the logging prefex.
function log:info() {
  logging_core_print "INFO" "$@"
}

function log:error() {
  logging_core_print "ERROR" "$@"
}

function log:warning() {
  logging_core_print "WARNING" "$@"
}

function log:script() {
  logging_core_print "SCRIPT" "$@"
}

function log:archive() {
  logging_core_print "ARCHIVE" "$@"
}

function print_bash_error_stack(){
  for ((i=1;i<${#FUNCNAME[@]}-1;i++)); do
      local fpath="$(realpath ${BASH_SOURCE[$i+1]})"
      log:error "$i: $fpath:${BASH_LINENO[$i]} @ ${FUNCNAME[$i]}"
  done
}

function assert() {
  if [ "$1" -ne 0 ]; then
    log:error "$2"
    print_bash_error_stack
    return "$1"
  fi
}

function assert_warn() {
  if [ "$1" -ne 0 ]; then
    log:warning "$2"
  fi
}
