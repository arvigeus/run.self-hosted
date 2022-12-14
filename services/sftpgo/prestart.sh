#!/bin/bash

RUN_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $RUN_SCRIPT_DIR/../../lib/logging.sh

dir=$RUN_SCRIPT_DIR/container-data

[ -z $RUN_ROOTLESS ] && RUN_ROOTLESS=0

if [ $RUN_ROOTLESS -eq 1 ]; then
    [ ! -d $dir ] && mkdir -p $dir 
    if [ -w $dir ]; then
        __log_debug "Unshare '$dir' with $PUID:$PGID"
        podman unshare chown $PUID:$PGID -R $dir
    fi
fi