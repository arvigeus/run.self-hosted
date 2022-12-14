#!/bin/bash

_services=()

_env_script_result=0

function __execute_env_script {
    local dir=$1
    local name=$2
    local service=$3
    local script=$(__get_env_file $dir $name $RUN_ENV "sh")
    if test -f "$script"; then
        __log_debug "Executing '$name' script for service '$service' from '$script'"
        chmod u+x "$script"
        sh $script
        _env_script_result=$?
        case $_env_script_result in
            0)
                ;;
            1)
                __log_warning "'$name' script for service '$service' exited with warnings"
                ;;
            *)
                __log_error "'$name' script for service '$service' exited with error code $_env_script_result"
                exit 1
                ;;
        esac
    else
        # When script is not found, consider it executed successfully
        _env_script_result=0
    fi
}

function __get_env_file {
    local dir=$1
    local filename=$2
    local env=$3
    local ext=$4

    [ ! -z "$env" ] && env=".$env"
    [ ! -z "$ext" ] && ext=".$ext"

    if test -f "$dir/$filename$env$ext"; then
        echo "$dir/$filename$env$ext"
    elif test -f "$dir/$filename$ext"; then
        echo "$dir/$filename$ext"
    else
        echo ""
    fi
}

function __load_services {
    if [ -z "$1" ]; then
        if [ -z "$RUN_SERVICES" ]; then
            _services=(services/*/)
            for i in "${!_services[@]}"
            do
                local tmp=${_services[$i]}
                tmp="${tmp#services/}"
                _services[$i]="${tmp%/}"
            done
            __log_debug "Loaded services from services directory"
        else
            _services=(${RUN_SERVICES//,/ })
            __log_debug "Loaded services from env var"
        fi
    else
        _services=( "$@" )
        __log_debug "Loaded services from parameters"
    fi
}