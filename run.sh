#!/bin/bash

RUN_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $RUN_SCRIPT_DIR/lib/logging.sh
source $RUN_SCRIPT_DIR/lib/services.sh

function prune {
    podman image prune -a
}

function start {
    # Load environment variables
    local env_file=$(__get_env_file $RUN_SCRIPT_DIR ".env" $RUN_ENV)
    export $(grep -v '^#' $env_file | xargs) > /dev/null 2>&1

    __load_services $*

    __log_message "Selected services: $(IFS=,; echo "${_services[*]}")"

    for service in ${_services[*]}
    do
        local dir=${RUN_SCRIPT_DIR}/services/$service

        if [ ! -d $dir ]; then
            __log_error "Cannot find service '$service' in '$dir'"
            continue
        fi

        __log_debug "Loading service '$service' from '$dir'"

        __execute_env_script $dir "prestart" $service
        [ $_env_script_result -ne 0 ] && continue

        local docker_compose_yaml=$(__get_env_file $dir "docker-compose" $RUN_ENV "yaml")
        [ -z "$docker_compose_yaml" ] && docker_compose_yaml=$(__get_env_file $dir "docker-compose" $RUN_ENV "yml")

        if test -f "$docker_compose_yaml"; then
            __log_debug "Running docker compose file '$docker_compose_yaml'"

            local service_env_file=$(__get_env_file $dir ".env" $RUN_ENV)
            if [ -z "$service_env_file" ]; then
                __log_debug "No environment file found in '$dir'"
                docker-compose -f ${docker_compose_yaml} up -d
            else
                __log_debug "Environment file selected: '$service_env_file'"
                docker-compose --env-file ${service_env_file} -f ${docker_compose_yaml} up -d 
            fi
        else
            __execute_env_script $dir "start" $service
            [ $_env_script_result -ne 0 ] && continue
        fi

        __execute_env_script $dir "poststart" $service
        [ $_env_script_result -ne 0 ] && continue
    done

    # Unset environment variables
    unset $(grep -v '^#' $env_file | sed -E 's/(.*)=.*/\1/' | xargs)
}

function stop {
    # Load environment variables
    local env_file=$(__get_env_file $RUN_SCRIPT_DIR ".env" $RUN_ENV)
    export $(grep -v '^#' $env_file | xargs) > /dev/null 2>&1

    __load_services $*

    __log_message "Selected services: $(IFS=,; echo "${_services[*]}")"

    # Reverse services order
    min=0
    max=$(( ${#_services[@]} -1 ))
    while [[ min -lt max ]]
    do
        # Swap current first and last elements
        local x="${_services[$min]}"
        _services[$min]="${_services[$max]}"
        _services[$max]="$x"

        # Move closer
        (( min++, max-- ))
    done

    for service in ${_services[*]}
    do
        local dir=${RUN_SCRIPT_DIR}/services/$service

        if [ ! -d $dir ]; then
            __log_error "Cannot find service '$service' in '$dir'"
            continue
        fi

        __log_debug "Stopping service '$service' from '$dir'"

        __execute_env_script $dir "prestop" $service
        [ $_env_script_result -ne 0 ] && continue

        local docker_compose_yaml=$(__get_env_file $dir "docker-compose" $RUN_ENV "yaml")
        [ -z "$docker_compose_yaml" ] && docker_compose_yaml=$(__get_env_file $dir "docker-compose" $RUN_ENV "yml")

        if test -f "$docker_compose_yaml"; then
            __log_debug "Stopping docker compose file '$docker_compose_yaml'"
            docker-compose -f ${docker_compose_yaml} down
        else
            __execute_env_script $dir "stop" $service
            [ $_env_script_result -ne 0 ] && continue
        fi

        __execute_env_script $dir "poststop" $service
        [ $_env_script_result -ne 0 ] && continue
    done

    # Unset environment variables
    unset $(grep -v '^#' $env_file | sed -E 's/(.*)=.*/\1/' | xargs)
}

function restart {
    stop $*
    start $*
}

function reset {
    __load_services $*

    __log_message "Selected services: $(IFS=,; echo "${_services[*]}")"

    for service in ${_services[*]}
    do
        local dir=${RUN_SCRIPT_DIR}/services/$service

        if [ ! -d $dir ]; then
            __log_error "Cannot find service '$service' in '$dir'"
            continue
        fi

        if [ -d "$dir/container-data" ]; then
            __log_debug "Removing 'container-data' from service '$service' in '$dir'"
            rm -rf "$dir/container-data"
        fi
    done
}

function script {
    # Load environment variables
    local env_file=$(__get_env_file $RUN_SCRIPT_DIR ".env" $RUN_ENV)
    export $(grep -v '^#' $env_file | xargs) > /dev/null 2>&1

    local script_dir=$RUN_SCRIPT_DIR/scripts
    local script_name=$1
    local script="$script_dir/$script_name"
    [ ! -f $script ] && [ -f "$script.sh" ] && script="$script.sh"

    if [ -f $script ]; then
        shift; local args=$@
        chmod u+x "$script"
        sh $script $args
    else
        __log_error "Cannot find script '$script_name' in '$script_dir'"
    fi

    # Unset environment variables
    unset $(grep -v '^#' $env_file | sed -E 's/(.*)=.*/\1/' | xargs)
}

function update {
    __load_services $*

    __log_message "Selected services: $(IFS=,; echo "${_services[*]}")"

    for service in ${_services[*]}
    do
        local dir=${RUN_SCRIPT_DIR}/services/$service

        local docker_compose_yaml=$(__get_env_file $dir "docker-compose" $RUN_ENV "yaml")
        [ -z "$docker_compose_yaml" ] && docker_compose_yaml=$(__get_env_file $dir "docker-compose" $RUN_ENV "yml")

        if test -f "$docker_compose_yaml"; then
            stop $service
            docker-compose -f ${docker_compose_yaml} pull
            docker-compose -f ${docker_compose_yaml} up --detach
            docker image prune -f
            start $service
        fi
    done
}

function backup {
    __load_services $*

    __log_message "Selected services: $(IFS=,; echo "${_services[*]}")"

    local archive_targets=""

    # Add main env files
    $(compgen -G "${RUN_SCRIPT_DIR}/.env*" > /dev/null) && archive_targets="$(find ${RUN_SCRIPT_DIR}/.env*  -printf "./%f ")"

    for service in ${_services[*]}
    do
        local dir=${RUN_SCRIPT_DIR}/services/$service

        [ ! -d $dir ] && continue
        [ -d $dir/container-data ] && archive_targets="${archive_targets} ./services/${service}/container-data"
        $(compgen -G "$dir/.env*" > /dev/null) && archive_targets="${archive_targets} $(find $dir/.env*  -printf "./services/${service}/%f ")"
    done

    local datestring=`date +'%Y-%m-%d'`

    if [ ! -z "$archive_targets" ]; then
        local backup_dir=${RUN_SCRIPT_DIR}/backups

        [ ! -d $backup_dir ] && mkdir $backup_dir

        __log_debug "Creating backup at '$backup_dir/$datestring.tar.gz':\n$(echo $archive_targets | tr " " "\n- ")"
        tar -czf -$archive_targets > $backup_dir/$datestring.tar.gz
        __log_info "Backup created at '$backup_dir/$datestring.tar.gz'"
    fi
}

function info {
    __load_services $*

    for service in ${_services[*]}
    do
        podman image inspect --format '{{json .}}' "$1" | jq -r '. | {Id: .Id, Digest: .Digest, RepoDigests: .RepoDigests, Labels: .Config.Labels}'
    done
}

function default {
    # Default task to execute
    help
}

function help {
    echo "$0 <task> <args>"
    echo "Tasks:"
    compgen -A function | awk '!/(^__)|(default)/' | cat -n
}

TIMEFORMAT="Task completed in %3lR"
time ${@:-default}
