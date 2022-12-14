#!/bin/bash

RUN_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $RUN_SCRIPT_DIR/../../lib/logging.sh

[ -z $RUN_ROOTLESS ] && RUN_ROOTLESS=0

if [ $RUN_ROOTLESS -eq 1 ]; then
  [ ! -d $DATA_DIR ] && mkdir -p $DATA_DIR
  if [ -w $DATA_DIR ]; then
    __log_info "Unshare '$DATA_DIR' with $PUID:$PGID"
    podman unshare chown $PUID:$PGID -R $DATA_DIR
  fi
fi