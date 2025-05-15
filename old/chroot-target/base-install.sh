#!/bin/bash
set -eauox pipefail

# This script runs within the chroot environment and does base
# configuration that applies to both the target and live rootfs

echo "Configuring WhistleKube Debian system within chroot environment..."
uname -a

# Make sure we don't get prompted
export DEBIAN_FRONTEND=noninteractive

# To ensure apt doesn't hang waiting for input
echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90assumeyes
echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/90recommends
echo 'APT::Install-Suggests "false";' > /etc/apt/apt.conf.d/90suggests
echo 'Dpkg::Options {"--force-confnew";}' > /etc/apt/apt.conf.d/90dpkgoptions

# Update package lists
echo "Updating package lists..."
apt-get update -v

# Install only the packages we need
echo "Installing packages..."
xargs apt-get install -y --no-install-recommends < ./packages.list

echo "Common setup done"
