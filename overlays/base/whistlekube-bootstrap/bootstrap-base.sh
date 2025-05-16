#!/bin/bash
# This script runs within the target chroot environment and configures the base system
# It runs after the overlay files have been applied

set -euxo pipefail

# Source the functions
source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

# Mount filesystems
mount_filesystems

# To ensure apt doesn't hang waiting for input
echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90assumeyes
echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/90recommends
echo 'APT::Install-Suggests "false";' > /etc/apt/apt.conf.d/90suggests
echo 'Dpkg::Options {"--force-confnew";}' > /etc/apt/apt.conf.d/90dpkgoptions

# Update and install packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
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
