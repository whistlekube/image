#!/bin/bash

# This script runs within the target chroot environment and configures the system
# It runs after the overlay files have been applied

set -euxo pipefail

# Source the functions
source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

# Mount filesystems
mount_filesystems

# Set default root password
echo "root:whistlekube" | chpasswd

export DEBIAN_FRONTEND=noninteractive

# Install busybox
apt-get update
apt-get install --no-install-recommends busybox-static

cd /bin
for cmd in sh ls cp mv ln mkdir rmdir rm cat echo dmesg mount umount ping ip; do
  ln -sf busybox $cmd
done
cd /

# Purge unnecessary packages
#apt-get purge --allow-remove-essential --auto-remove -y \
#  bsdutils  \
#  debian-archive-keyring  \
#  debianutils  \
#  debootstrap  \
#  diffutils  \
#  distro-info  \
#  distro-info-data  \
#  findutils  \
#  gcc-14-base  \
#  grep  \
#  gzip  \
#  hostname  \
#  perl-base


##  bash       \
##  findutils*  \
##  grep*       \
##  sed*        \
##  sysvinit-utils\
##  udev

# Purge unnecessary packages
#apt-get purge --allow-remove-essential --auto-remove -y \
#  bash*       \
#  coreutils*  \
#  sed*        \
#  grep*       \
#  findutils*  \
#  sysvinit-utils\
#  util-linux  \
#  udev

# Clean apt caches to reduce image size
#echo "Cleaning apt caches..."
#rm -rf /var/lib/apt/lists/* /var/log/* /tmp/*

# Remove apt and dpkg
#apt-get purge --auto-remove -y \
#  apt* \
#  dpkg*

# Unmount filesystems
unmount_filesystems
