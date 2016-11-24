#!/bin/bash
#
# Usage:
#
#   Implement a callback function named 'run' in your script and include this
# library at the END of your script. The 'run' function will be called at a
# regular interval, defined by the variable 'MINILOOP_INTERVAL'. This variable
# can be overwritten in your script if you wish to change the interval. The
# variable 'MINILOOP_SERVER_ADDRESS' is mandatory and HAS to be defined in your
# script
#
#
# Debugging:
#
#   When running this script with the 'MINILOOP_DEBUG_MODE' set to a value
# different than 0, the script will print to metrics to the consol instead of
# sending them to the server. Example:
#   $ MINILOOP_DEBUG_MODE=1 myScript.sh
#

#
# Defaults
#
# Local instance name
MINILOOP_HOSTNAME="${MINILOOP_HOSTNAME:-$HOSTNAME}"
# Interval between execution of the run function
MINILOOP_INTERVAL="${MINILOOP_INTERVAL:-5}"
# Timeout for the payload
MINILOOP_TIMEOUT="${MINILOOP_TIMEOUT:-${MINILOOP_INTERVAL}}"
# Metrics server port
MINILOOP_SERVER_PORT="${MINILOOP_SERVER_PORT:-8089}"
# Is the script running in debug mode
MINILOOP_DEBUG_MODE="${MINILOOP_DEBUG_MODE:-0}"


#
# Check that the settings are valid
#
validateSettings() {
  # Hostname
  [[ -z ${MINILOOP_HOSTNAME+x} ]] \
    && error 'The hostname is not defined' \
    && exit 1

  # Interval
  [[ -z ${MINILOOP_INTERVAL+x} ]] \
    && error 'The interval is not defined' \
    && exit 1
  [[ ${MINILOOP_INTERVAL} -le 0 ]] \
    && error 'The interval cannot be lower or equal 0' \
    && exit 1

  # Timeout
  [[ -z ${MINILOOP_TIMEOUT+x} ]] \
    && error 'The timeout is undefined' \
    && exit 1
  [[ ${MINILOOP_TIMEOUT} -le 0 ]] \
    && error 'The timeout cannot be lower or equal 0' \
    && exit 1
  [[ ${MINILOOP_TIMEOUT} -gt ${MINILOOP_INTERVAL} ]] \
    && error 'The timeout cannot be larger that the interval' \
    && exit 1

  # Address
  [[ -z ${MINILOOP_SERVER_ADDRESS+x} ]] \
    && error 'The server address is undefined' \
    && exit 1

  # Port
  [[ -z ${MINILOOP_SERVER_PORT+x} ]] \
    && error 'The server port is undefined' \
    && exit 1
  [[ ${MINILOOP_SERVER_PORT} -lt 1 ]] \
    && error 'The server port has to be greater or equal to 1' \
    && exit 1
  [[ ${MINILOOP_SERVER_PORT} -gt 65535 ]] \
    && error 'The server port has to be lower or equal to 65535' \
    && exit 1
}

#
# Unix timestamp in nanoseconds
#
now() {
  date +%s%N
}


#
# Send data over UDP
#
send() {
  local device="/dev/udp/${MINILOOP_SERVER_ADDRESS}/${MINILOOP_SERVER_PORT}"

  while read -r message; do
    if [[ ${MINILOOP_DEBUG_MODE} -eq 0 ]]; then
      printf '%s\n' "${message}" >"${device}"
    else
      printf '%s\n' "${message}"
    fi
  done
}


#
# Time compensation for the main loop
#
compensatedSleep() {
  local start_time="${1}"
  local end_time="${SECONDS}"
  local duration="$(( ${MINILOOP_INTERVAL} - ( ${end_time} - ${start_time} ) ))"

  if [[ ${duration} -lt 0 ]]; then
    sleep 0
  else
    sleep "${duration}"
  fi
}


#
# Check if a timeout has been exceeded
#
timeoutExceeded() {
  local start_time="${1}"

  [[ $(( ${SECONDS} - ${start_time} )) -ge ${MINILOOP_TIMEOUT} ]]
}


#
# Check if a process is alive
#
isRunning() {
  local pid="${1}"

  kill -0 "${pid}" >/dev/null 2>&1
}


#
# Print logs to the consol
#
logOutput() {
  while read -r input; do
    printf '%s\n' "${input}"
  done
}


#
# Generic logger
#
genericLog() {
  printf '%s\n' "${1}" >&2
}


#
# Logging API
#
debug() {
  genericLog "[DEBUG] ${1}"
}

info() {
  genericLog "[INFO] ${1}"
}

notice() {
  genericLog "[NOTICE] ${1}"
}

warning() {
  genericLog "[WARN] ${1}"
}

error() {
  genericLog "[ERR] ${1}"
}

critical() {
  genericLog "[CRIT] ${1}"
}

alert() {
  genericLog "[ALERT] ${1}"
}

emergency() {
  genericLog "[EMERG] ${1}"
}


#
# Terminate a process
#
terminate() {
  kill -9 "${pid}" >/dev/null 2>&1
}


#
# Main loop
#
main() {
  validateSettings

  while true; do
    local start_time="${SECONDS}"
    local pid=''

    # Pipe 'run' stdout to 'send' stdin
    # Pipe 'send' stdout to 'log' stdin
    # Pipe 'run' and 'send' stderr to 'log' stdin
    ( { run | send; } 2>&1 | logOutput )&
    pid="${!}"

    while [[ $( isRunning "${pid}" ) ]]; do
      if [[ $( timeoutExceeded "${start_time}" ) ]]; then
        terminate "${pid}"
      fi
    done

    compensatedSleep "${start_time}"
  done
}
main
