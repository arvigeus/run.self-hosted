#!/bin/bash

exec 3>&2 # logging stream (file descriptor 3) defaults to STDERR

log_level_message=0
log_level_critical=1
log_level_error=2
log_level_warn=3
log_level_inf=4
log_level_debug=5

_log_verbosity=""

function __log_init {
    case $RUN_VERBOSITY in
        notify | 0)
            _log_verbosity=$log_level_message
            ;;
        critical | 1)
            _log_verbosity=$log_level_critical
            ;;
        error | 2)
            _log_verbosity=$log_level_error
            ;;
        warning | 3)
            _log_verbosity=$log_level_warn
            ;;
        info | 4)
            _log_verbosity=$log_level_inf
            ;;
        debug | 5)
            _log_verbosity=$log_level_debug
            ;;
        quiet | none)
            _log_verbosity=-1
            ;;
        *)
            _log_verbosity=$log_level_inf
            ;;
    esac
}

__log_message() { __log $log_level_message "$1"; } # Always prints
__log_critical() { __log $log_level_critical "\e[31mCRITICAL: $1"; }
__log_error() { __log $log_level_error "\e[31mERROR: $1"; }
__log_warning() { __log $log_level_warn "\e[33mWARNING: $1"; }
__log_info() { __log $log_level_inf "\e[36mINFO: $1"; } # "info" is already a command
__log_debug() { __log $log_level_debug "\e[90mDEBUG: $1"; }
__log() {
    [ -z $_log_verbosity ] && __log_init
    if [ $_log_verbosity -ge $1 ]; then
        local datestring=`date +'%Y-%m-%d %H:%M:%S'`
        # Expand escaped characters, wrap at 70 chars, indent wrapped lines
        echo -e "$datestring $2\e[0m" >&3
    fi
}