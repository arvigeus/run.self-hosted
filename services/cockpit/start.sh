#!/bin/bash

RUN_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $RUN_SCRIPT_DIR/../../lib/logging.sh

if [ "$(systemctl is-active cockpit.socket)" = "inactive" ]; then
    __log_message "Starting Cockpit service"
    sudo systemctl start cockpit.socket
fi

__log_info "Cockpit Service: $(systemctl is-active cockpit.socket)"

if [ ! -z "$RUN_HOST" ] && [ ! -z "$RUN_PROTOCOL" ]; then
    __log_debug "Cockpit requested on custom hostname"
    cockpit_conf=$(cat $(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/container-config/cockpit.conf)
    cockpit_conf="${cockpit_conf//"\$RUN_HOST"/$RUN_HOST}"
    cockpit_conf="${cockpit_conf//"\$RUN_PROTOCOL"/$RUN_PROTOCOL}"
    if test -f "/etc/cockpit/cockpit.conf"; then
        __log_debug "'/etc/cockpit/cockpit.conf' already exists"
        etc_cockpit=$(cat /etc/cockpit/cockpit.conf)
        if [ "$etc_cockpit" != "$cockpit_conf" ]; then
            __log_message "Updating cockpit config for $RUN_PROTOCOL://system.$RUN_HOST"
            sudo sh -c "echo '$cockpit_conf' > /etc/cockpit/cockpit.conf"
        else
            __log_debug "'/etc/cockpit/cockpit.conf' is up to date"
        fi
    else
        __log_message "Creating cockpit config for $RUN_PROTOCOL://system.$RUN_HOST"
        sudo sh -c "echo '$cockpit_conf' > /etc/cockpit/cockpit.conf"
    fi
fi