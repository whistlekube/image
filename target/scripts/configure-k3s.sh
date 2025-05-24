#!/bin/bash

# Configure k3s in the rootfs chroot environment

set -euxo pipefail

# Install  containerd
mkdir -p /var/lib/containerd
mkdir -p /etc/cni/net.d
mkdir -p /etc/containerd
systemctl enable containerd

# Install k3s
mkdir -p /var/lib/rancher/k3s
mkdir -p /etc/rancher/k3s
mkdir -p /var/log
systemctl enable k3s

ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
