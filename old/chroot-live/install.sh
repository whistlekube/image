#!/bin/bash
set -euo pipefail

# This script runs inside the chroot to configure the installer system

CHROOT_INSTALLER_DIR="${CHROOT_INSTALLER_DIR:-/whistlekube-chroot-installer}"

echo "Configuring WhistleKube Installer system within chroot environment..."

# Make sure we don't get prompted
export DEBIAN_FRONTEND=noninteractive

# Prevent services from starting during installation
#cat > /usr/sbin/policy-rc.d <<EOF
##!/bin/sh
#exit 101
#EOF
#chmod +x /usr/sbin/policy-rc.d

# Install packages
echo "Installing packages..."
xargs apt-get install -y --no-install-recommends < "${CHROOT_INSTALLER_DIR}/layer/packages.list"

# Apply overlay
echo "Applying overlay..."
cp -r /overlay/* /

# Configure networking
#cat > /etc/network/interfaces << EOF
## The loopback network interface
#auto lo
#iface lo inet loopback
#
## The primary network interface
#allow-hotplug eth0
#iface eth0 inet dhcp
#EOF

# Create a minimal fstab
cat > /etc/fstab << EOF
# /etc/fstab: static file system information
LABEL=root / ext4 defaults 0 1
EOF

# Build initramfs
echo "Building initramfs..."
#update-initramfs -c -k $(uname -r)

# Set up locales for en_US.UTF-8
#echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
#echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
#rm -f /etc/locale.gen
#echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
#locale-gen
