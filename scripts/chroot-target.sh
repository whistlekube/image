#!/bin/bash
set -eauox pipefail

# This script runs within the target chroot environment and configures the system
# It runs after the overlay files have been applied

export DEBIAN_FRONTEND=noninteractive

mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts

# Update and install packages
apt-get update
apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    grub-pc \
    grub-efi-amd64 \
    systemd-sysv

# Configure locale
locale-gen
update-locale LANG=en_US.UTF-8

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*

# Unmount filesystems
umount /proc
umount /sys
umount /dev/pts
