#!/bin/bash

#
# This script collect values from /proc/loadavg and format them to the influxdb
# line protocol. Replace the value from MINILOOP_SERVER_ADDRESS by the address
# of your InfluxDB server.
#
proc_file='/proc/loadavg'
MINILOOP_SERVER_ADDRESS='127.0.0.1'

run() {
  local timestamp="$( now )"

  #
  # Check if the proc_file exists
  #
  [[ ! -f ${proc_file} ]] \
    && error "Cannot open ${proc_file}" \
    && exit 1

  #
  # Read from the pseudo-file
  #
  IFS="${IFS}/"
  read -r one five fifteen running total pid <"${proc_file}"

  #
  # Load average
  #
  printf '%s,%s %s %s\n' \
    'load' \
    "instance=${metrics_hostname}" \
    "1m=${one},5m=${five},15m=${fifteen}" \
    "${timestamp}"

  #
  # Processes
  #
  printf '%s,%s %s %s\n' \
    'processes' \
    "instance=${metrics_hostname}" \
    "running=${running},total=${total},last_pid=${pid}" \
    "${timestamp}"
}

. miniloop.sh
