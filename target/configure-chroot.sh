#!/bin/bash

# This script is used to configure the chroot environment
# It is called by the Dockerfile when building the installer rootfs
# and is run within the chroot environment
# 

rootfs="$1"

set -euxo pipefail

# Delete the kernel and initrd images, these will live outside the squashfs
rm -f ${rootfs}/boot/*

echo "TTYPath=/dev/tty4" >> ${rootfs}/etc/systemd/journald.conf

# Disable all networking services
systemctl disable systemd-networkd || true
systemctl disable systemd-resolved || true
systemctl disable networking || true
systemctl mask NetworkManager || true
systemctl mask systemd-networkd || true
systemctl mask systemd-resolved || true
systemctl mask networking || true

# Set the root password
echo "root:whistle" | chpasswd
