#!/bin/bash

# This script is used to configure the chroot environment
# It is called by the Dockerfile when building the installer rootfs
# and is run within the chroot environment
# 

rootfs="$1"

set -euxo pipefail

# Systemd output on tty4
echo "TTYPath=/dev/tty4" >> ${rootfs}/etc/systemd/journald.conf

# Enable the whistlekube-installer service so it runs on boot
systemctl enable whistlekube-installer.service

# Update the initramfs
update-initramfs -u -k all
