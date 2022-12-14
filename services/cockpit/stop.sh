#!/bin/bash

RUN_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $RUN_SCRIPT_DIR/../../lib/logging.sh

if [ "$(systemctl is-active cockpit.socket)" = "active" ]; then
    __log_message "Stopping Cockpit service"
    sudo systemctl stop cockpit.socket
fi

__log_info "Cockpit Service: $(systemctl is-active cockpit.socket)"