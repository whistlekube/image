#!/bin/bash
# This script runs within the live chroot environment and configures the live system

set -euxo pipefail

# Source the functions
source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

# Mount filesystems
mount_filesystems

export DEBIAN_FRONTEND=noninteractive

# Install packages specific to the live environment
apt-get update -y
apt-get install -y --no-install-recommends \
    live-boot \
    live-config \
    live-config-systemd \
    dialog \
    squashfs-tools \
    parted gdisk e2fsprogs lvm2 cryptsetup dosfstools \
    ca-certificates

# Enable installer service
systemctl enable whistlekube-installer

# Unmount filesystems
unmount_filesystems
