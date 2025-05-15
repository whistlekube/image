#!/bin/bash
set -eauox

# This script contains the generic install script for the chroot environment
# It is used to configure the chroot environment, install packages, and configure the system
# It takes two arguments, the path to the target rootfs and the path to the install script
# The rootfs is expected to have debootstrap run already and a custom install.sh script
# at the root of the target rootfs

# Parse and validate arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <rootfs-path> <install-script-path>"
    exit 1
fi
ROOTFS_PATH="$1"
INSTALL_SCRIPT_PATH="$2"

# Setup mounts for the chroot environment
mkdir -p "${ROOTFS_PATH}/proc"
mount -t proc proc "${ROOTFS_PATH}/proc"
mkdir -p "${ROOTFS_PATH}/sys"
mount -t sysfs sysfs "${ROOTFS_PATH}/sys"
mkdir -p "${ROOTFS_PATH}/dev"
mount --bind /dev "${ROOTFS_PATH}/dev"
mkdir -p "${ROOTFS_PATH}/dev/pts"
mount --bind /dev/pts "${ROOTFS_PATH}/dev/pts"
# Make sure /dev/shm is properly set up for systemd
mkdir -p "${ROOTFS_PATH}/dev/shm"
mount -t tmpfs shm "${ROOTFS_PATH}/dev/shm"

# Run the install script in the chroot
chroot "${ROOTFS_PATH}" "${INSTALL_SCRIPT_PATH}"

### Cleanup ###
# Unmount the mounts
umount -l "${ROOTFS_PATH}/dev/shm"
umount -l "${ROOTFS_PATH}/dev/pts"
umount -l "${ROOTFS_PATH}/dev"
umount -l "${ROOTFS_PATH}/sys"
umount -l "${ROOTFS_PATH}/proc"
