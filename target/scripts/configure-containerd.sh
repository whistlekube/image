#!/bin/bash

# Configure kubernetes in the rootfs chroot environment

set -euxo pipefail

# Install  containerd
mkdir -p /var/lib/containerd
mkdir -p /etc/cni/net.d
mkdir -p /etc/containerd
systemctl enable containerd

## # Link base CNI plugins to where k3s expects
## mkdir -p /opt/cni/bin
## for bin in /usr/lib/cni/*; do
##   ln -sf "$bin" /opt/cni/bin/
## done
