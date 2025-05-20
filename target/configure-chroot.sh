#!/bin/bash

# This script is used to configure the chroot environment
# It is called by the Dockerfile when building the installer rootfs
# and is run within the chroot environment
# 

rootfs="$1"

set -euxo pipefail

# Delete the kernel and initrd images, these will live outside the squashfs
rm -f ${rootfs}/boot/vmlinuz-*
rm -f ${rootfs}/boot/initrd.img-*

echo "TTYPath=/dev/tty4" >> ${rootfs}/etc/systemd/journald.conf

# Install k3s
mkdir -p ${rootfs}/etc/rancher/k3s
mkdir -p ${rootfs}/var/lib/rancher/k3s/agent/images
mkdir -p ${rootfs}/var/lib/rancher/k3s/server/manifests
systemctl enable k3s

# Install base CNI plugins and link them to where k3s expects
mkdir -p ${rootfs}/opt/cni/bin
for bin in ${rootfs}/usr/lib/cni/*; do
  ln -sf "$bin" ${rootfs}/opt/cni/bin/
done

# Configure CNI plugin
mkdir -p ${rootfs}/etc/cni/net.d
cat <<'EOF' > ${rootfs}/etc/cni/net.d/10-loopback.conf
{
  "cniVersion": "0.4.0",
  "name": "none-network",
  "type": "none"
}
EOF

# Disable all networking services
systemctl disable systemd-networkd || true
systemctl mask systemd-networkd || true

# Set the root password
echo "root:wk" | chpasswd
