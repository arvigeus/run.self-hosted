#!/bin/bash

# https://rootlesscontaine.rs/
# https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md
# https://linuxhandbook.com/rootless-podman/

echo "Enabling CPU, CPUSET, and I/O delegation"
sudo mkdir -p /etc/systemd/system/user@.service.d
cat <<EOF | sudo tee /etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
sudo systemctl daemon-reload

echo "Enabling user namespaces"
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
grep $USER /etc/subuid /etc/subgid

echo "Setting sysctl"
podman_rootless_conf="/etc/sysctl.d/66-podman-rootless.conf"
sudo sysctl -w "net.ipv4.ping_group_range=0 2000000"
sudo echo "net.ipv4.ping_group_range=0 2000000" | sudo tee $podman_rootless_conf >/dev/null
sudo sysctl -w "net.ipv4.ip_unprivileged_port_start=0"
sudo echo "net.ipv4.ip_unprivileged_port_start=0" | sudo tee -a $podman_rootless_conf >/dev/null