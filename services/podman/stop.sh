#!/bin/bash

RUN_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $RUN_SCRIPT_DIR/../../lib/logging.sh

[ -z $RUN_ROOTLESS ] && RUN_ROOTLESS=0
[ -z $DOCKER_NETWORK_CLEANUP ] && DOCKER_NETWORK_CLEANUP=0

if [ $RUN_ROOTLESS -eq 1 ]; then
    __log_debug "Stopping Podman in rootless mode"

    if [ "$(systemctl --user is-active podman.socket)" = "active" ]; then
        __log_debug "Stopping Podman service"
        systemctl --user stop podman.socket
    fi

    __log_info "Podman Service: $(systemctl --user is-active podman.socket)"

    if [ $DOCKER_NETWORK_CLEANUP -eq 1 ]; then
        __log_debug "Network cleanup requested"
        if [ -n $DOCKER_NETWORK ]; then
            __log_debug "Network '$DOCKER_NETWORK' requested for cleanup"
            podman network exists $DOCKER_NETWORK
            podman_network_not_exists=$?
            if [ $podman_network_not_exists -eq 0 ]; then
                __log_info "Removing network '$DOCKER_NETWORK'"
                podman network rm $DOCKER_NETWORK 1> /dev/null
            fi
        fi
    fi
else
    if [ "$(systemctl is-active podman.socket)" = "active" ]; then
        __log_info "Stopping Podman service"
        sudo systemctl stop podman.socket
    fi

    __log_info "Podman Service: $(systemctl is-active podman.socket)"

    if [ $DOCKER_NETWORK_CLEANUP -eq 1 ]; then
        __log_debug "Network cleanup requested"
        if [ ! -z $DOCKER_NETWORK ]; then
            __log_info "Network '$DOCKER_NETWORK' requested for cleanup"
            sudo podman network exists $DOCKER_NETWORK
            podman_network_not_exists=$?
            if [ $podman_network_not_exists -eq 0 ]; then
                __log_info "Removing network '$DOCKER_NETWORK'"
                sudo podman network rm $DOCKER_NETWORK 1> /dev/null
            fi
        fi
    fi
fi