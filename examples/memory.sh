#!/bin/bash

#
# This script reads the memory statistics from /proc/meminfo and format them to
# InfluxDB line protocol. Replace the value from MINILOOP_SERVER_ADDRESS by the
# address of your own InfluxDB server.
#
proc_file='/proc/meminfo'
MINILOOP_SERVER_ADDRESS='127.0.0.1'

run() {
  awk -v timestamp="$( now )" \
      -v instance="${MINILOOP_HOSTNAME}" '

    /^MemTotal:/      {total=$2*1024}
    /^MemFree:/       {free=$2*1024}
    /^MemAvailable:/  {available=$2*1024}
    /^Buffers:/       {buffers=$2*1024}
    /^Cached:/        {cached=$2*1024}
    /^Active:/        {active=$2*1024}
    /^Inactive:/      {inactive=$2*1024}
    /^SwapTotal:/     {swap_total=$2*1024}
    /^SwapFree:/      {swap_free=$2*1024}
    /^SwapCached:/    {swap_cached=$2*1024}

    END {

      # Use floats with a precision of 0 to store the [large] values
      format="memory,instance=%.0f total=%.0f,free=%.0f,available=%.0f,buffers=%.0f,cached=%.0f,active=%.0f,inactive=%.0f,swap_total=%.0f,swap_free=%.0f,swap_cached=%.0f %.0f\n"

      printf format, \
        instance, \
        total, \
        free, \
        available, \
        buffers, \
        cached, \
        active, \
        inactive, \
        swap_total, \
        swap_free, \
        swap_cached, \
        timestamp

    }' "${proc_file}"
}

. miniloop.sh
