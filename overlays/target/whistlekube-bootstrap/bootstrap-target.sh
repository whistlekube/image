#!/bin/bash

# This script runs within the target chroot environment and configures the system
# It runs after the overlay files have been applied

set -euxo pipefail

# Source the functions
source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

# Mount filesystems
mount_filesystems

export DEBIAN_FRONTEND=noninteractive

# Install packages specific to the target environment
apt-get update -y
apt-get install -y --no-install-recommends \
    grub-common \
    grub2-common \
    ucf

# Get grub packages from the live installer environment
mkdir -p /grub-debs
pushd /grub-debs
apt-get download \
    grub-pc \
    grub-pc-bin \
    grub-efi-amd64 \
    grub-efi-amd64-bin \
    efibootmgr
popd

# Set default root password
echo "root:whistlekube" | chpasswd

# Cleanup apt cache
cleanup_apt

# Unmount filesystems
unmount_filesystems
