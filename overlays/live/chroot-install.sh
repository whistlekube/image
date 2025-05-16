#!/bin/bash
set -eauox pipefail

# This script runs within the live chroot environment and configures the live system

export DEBIAN_FRONTEND=noninteractive

mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts

# Update and install packages
apt-get update
apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    systemd-sysv \
    locales \
    live-boot \
    live-config \
    live-config-systemd \
    dialog \
    parted gdisk e2fsprogs xfsprogs btrfs-progs lvm2 cryptsetup dosfstools \
    ca-certificates

# Configure locale
locale-gen
update-locale LANG=en_US.UTF-8

# Enable installer service
#systemctl enable whistlekube-installer

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*

# Unmount filesystems
umount /proc
umount /sys
umount /dev/pts
