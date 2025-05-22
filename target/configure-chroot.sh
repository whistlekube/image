#!/bin/bash

# This script is used to configure the chroot environment
# It is called by the Dockerfile when building the installer rootfs
# and is run within the chroot environment
# 

rootfs="$1"

set -euxo pipefail

echo "TTYPath=/dev/tty4" >> ${rootfs}/etc/systemd/journald.conf

# Install k3s
mkdir -p ${rootfs}/etc/rancher/k3s
mkdir -p ${rootfs}/var/lib/rancher/k3s/agent/images
mkdir -p ${rootfs}/var/lib/rancher/k3s/server/manifests
systemctl enable k3s

# Enable whistle-netd
systemctl enable whistle-netd

# Install base CNI plugins and link them to where k3s expects
mkdir -p ${rootfs}/opt/cni/bin
for bin in ${rootfs}/usr/lib/cni/*; do
  ln -sf "$bin" ${rootfs}/opt/cni/bin/
done

# Disable all networking services
systemctl disable networking || true
systemctl disable systemd-networkd || true
systemctl disable systemd-resolved || true
systemctl mask systemd-networkd || true
systemctl mask systemd-resolved || true
systemctl mask networking || true

# Set the root password
echo "root:wk" | chpasswd
