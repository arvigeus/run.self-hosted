#!/bin/bash

RUN_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $RUN_SCRIPT_DIR/../../lib/logging.sh

[ -z $RUN_ROOTLESS ] && RUN_ROOTLESS=0

if [ $RUN_ROOTLESS -eq 1 ]; then
  __log_debug "Running Podman in rootless mode"
  if [ "$(systemctl --user is-active podman.socket)" = "inactive" ]; then
    __log_debug "Starting Podman service"
      systemctl --user start podman.socket
  fi

  __log_info "Podman Service: $(systemctl --user is-active podman.socket)"

  __log_debug "Testing Podman socket status"
  server_status=$(curl -s -H "Content-Type: application/json" --unix-socket /var/run/user/$UID/podman/podman.sock http://localhost/_ping)
  if [ "$server_status" != "OK" ]; then
      __log_critical "Unexpected podman status: $server_status"
      exit 3
  fi
  __log_debug "Podman socket status: $server_status"

  __log_debug "Checking required environment variables"

  if [ "$DOCKER_HOST" != "unix:$XDG_RUNTIME_DIR/podman/podman.sock" ]; then
    __log_critical "'DOCKER_HOST' environment variable must be set to 'unix:${XDG_RUNTIME_DIR}/podman/podman.sock'"
    exit 3
  fi

  if [ "$DOCKER_SOCK" != "$XDG_RUNTIME_DIR/podman/podman.sock" ]; then
    __log_critical "'DOCKER_SOCK' environment variable must be set to '${XDG_RUNTIME_DIR}/podman/podman.sock'"
    exit 3
  fi

  if [ ! -z $DOCKER_NETWORK ]; then
    __log_debug "Requested network '$DOCKER_NETWORK'"
    podman network exists $DOCKER_NETWORK
    podman_network_not_exists=$?
    if [ $podman_network_not_exists -eq 1 ]; then
      __log_info "Creating network '$DOCKER_NETWORK'"
      if [ "$(podman network create $DOCKER_NETWORK)" != "$DOCKER_NETWORK" ]; then
        __log_critical "Unable to create network '$DOCKER_NETWORK'"
        exit 3
      else
      __log_debug "Network created: '$DOCKER_NETWORK'"
      fi
    else
      __log_debug "Network '$DOCKER_NETWORK' already exists"
    fi
  fi

  if [ ! -d $DATA_DIR ]; then
    __log_message "Creating directory '$DATA_DIR' for user '$USER'"
    sudo mkdir -p $DATA_DIR
    sudo chown -R $USER:$USER $DATA_DIR
    sudo chmod -R a=,a+rX,u+w,g+w $DATA_DIR
  fi

  podman_warnings=0

  if [ ! -f /sys/fs/cgroup/cgroup.controllers ]; then
    __log_warning "cgroup v2 is not enabled"
    #podman_warnings=1
  else
    __log_debug "cgroup v2 is enabled"
  fi

  systemd_delegations=$(cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers)
  delegations=("cpuset" "cpu" "io" "memory" "pids")
  for delegation in ${delegations[*]}
  do
    if ! grep -q "$delegation" <<< "$systemd_delegations"; then
      __log_warning "Systemd delegations does not contain '$delegation'"
      podman_warnings=1
    else
      __log_debug "Systemd delegations contains '$delegation'"
    fi
  done

  if ! grep -q "$USER:" "/etc/subuid"; then
    __log_warning "'$USER' not found into '/etc/subuid'"
    podman_warnings=1
  fi
  if ! grep -q "$USER:" "/etc/subgid"; then
    __log_warning "'$USER' not found into '/etc/subgid'"
    podman_warnings=1
  fi

  sysctl_ping_group_range=$(sysctl --value --ignore net.ipv4.ping_group_range)
  if [ -z "$sysctl_ping_group_range" ]; then
    __log_warning "'net.ipv4.ping_group_range' is not set"
    podman_warnings=1
  fi
  sysctl_ip_unprivileged_port_start=$(sysctl --value --ignore net.ipv4.ip_unprivileged_port_start)
  if [ $sysctl_ip_unprivileged_port_start -gt 443 ]; then
    __log_warning "'net.ipv4.ip_unprivileged_port_start' is set to $sysctl_ip_unprivileged_port_start, should be less than or equal 443"
    podman_warnings=1
  fi

  if [ $podman_warnings -ne 0 ]; then
    __log_warning "Try running './run.sh script podman.rootless' to correct this"
    exit 1
  fi
else
  __log_debug "Running Podman as root"

  if [ "$(systemctl is-active podman.socket)" = "inactive" ]; then
      __log_message "Starting Podman service"
      sudo systemctl start podman.socket
  fi

  __log_info "Podman Service: $(systemctl is-active podman.socket)"

  __log_message "Testing Podman socket status"
  server_status=$(sudo curl -s -H "Content-Type: application/json" --unix-socket /var/run//podman/podman.sock http://localhost/_ping)
  if [ "$server_status" != "OK" ]; then
      __log_critical "Unexpected podman status: $server_status"
      exit 3
  fi

  if [ "$DOCKER_HOST" != "unix:///run/podman/podman.sock" ]; then
    __log_critical "'DOCKER_HOST' environment variable must be set to 'unix:///run/podman/podman.sock'"
    exit 3
  fi

  if [ "$DOCKER_SOCK" != "/var/run/podman/podman.sock" ]; then
    __log_critical "'DOCKER_SOCK' environment variable must be set to '/var/run/podman/podman.sock'"
    exit 3
  fi

  if [ ! -z $DOCKER_NETWORK ]; then
    __log_message "Requested network '$DOCKER_NETWORK'"
    sudo podman network exists $DOCKER_NETWORK
    podman_network_not_exists=$?
    if [ $podman_network_not_exists -eq 1 ]; then
      __log_message "Creating network '$DOCKER_NETWORK'"
      if [ "$(sudo podman network create $DOCKER_NETWORK)" != "$DOCKER_NETWORK" ]; then
        __log_critical "Unable to create network '$DOCKER_NETWORK'"
        exit 3
      else
        __log_debug "Network created: '$DOCKER_NETWORK'"
      fi
    else
      __log_debug "Network '$DOCKER_NETWORK' already exists"
    fi
  fi

  if [ ! -d $DATA_DIR ]; then
    __log_message "Creating directory '$DATA_DIR'"
    sudo mkdir -p $DATA_DIR
  fi
fi