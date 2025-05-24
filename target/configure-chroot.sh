#!/bin/bash

# This script is used to configure the chroot environment
# It is called by the Dockerfile when building the installer rootfs
# and is run within the chroot environment
# 

set -euxo pipefail

echo "TTYPath=/dev/tty4" >> /etc/systemd/journald.conf

# Enable whistle-netd
systemctl enable whistle-netd

# Disable all networking services
systemctl disable systemd-networkd || true
systemctl disable systemd-resolved || true
systemctl mask systemd-networkd || true
systemctl mask systemd-resolved || true

# Set the root password
echo "root:wk" | chpasswd
