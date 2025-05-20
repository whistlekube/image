#!/bin/bash

# This script is used to configure the chroot environment
# It is called by the Dockerfile when building the installer rootfs
# and is run within the chroot environment
# 

rootfs="$1"

set -euxo pipefail

rm -f ${rootfs}/boot/*

echo "TTYPath=/dev/tty4" >> ${rootfs}/etc/systemd/journald.conf

systemctl enable whistlekube-installer.service

