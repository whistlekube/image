#!/bin/bash

# Configure kubernetes in the rootfs chroot environment

rootfs="$1"

set -euxo pipefail

# Install kubernetes
mkdir -p ${rootfs}/etc/kubernetes
mkdir -p ${rootfs}/var/lib/rancher/k3s/agent/images
mkdir -p ${rootfs}/var/lib/rancher/k3s/server/manifests
systemctl enable k3s

# Link base CNI plugins to where k3s expects
mkdir -p ${rootfs}/opt/cni/bin
for bin in ${rootfs}/usr/lib/cni/*; do
  ln -sf "$bin" ${rootfs}/opt/cni/bin/
done
