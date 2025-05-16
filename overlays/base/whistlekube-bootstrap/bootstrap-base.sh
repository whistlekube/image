#!/bin/bash
# This script runs within the target chroot environment and configures the base system
# It runs after the overlay files have been applied

set -euxo pipefail

# Source the functions
source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

# Mount filesystems
mount_filesystems

# Update and install packages
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    systemd-sysv \
    locales \
    zstd

# Configure locale
locale-gen
update-locale LANG=en_US.UTF-8

# Unmount filesystems
unmount_filesystems
