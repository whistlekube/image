#!/bin/bash
set -eauox pipefail

# This script runs within the chroot environment and does common setup tasks

# To ensure apt doesn't hang waiting for input
echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90assumeyes
echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/90recommends
echo 'APT::Install-Suggests "false";' > /etc/apt/apt.conf.d/90suggests
echo 'Dpkg::Options {"--force-confnew";}' > /etc/apt/apt.conf.d/90dpkgoptions

# Update package lists
echo "Updating package lists..."
apt-get update -v
