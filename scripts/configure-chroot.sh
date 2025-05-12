#!/bin/bash
set -euo pipefail

# This script runs inside the chroot to configure the minimal system

echo "Configuring minimal Debian system..."

# Make sure we don't get prompted
export DEBIAN_FRONTEND=noninteractive

# Prevent services from starting during installation
cat > /usr/sbin/policy-rc.d <<EOF
#!/bin/sh
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

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
xargs apt-get install -y --no-install-recommends < packages.list

# Remove unnecessary packages
echo "Removing unnecessary packages..."
apt-get remove -y --purge installation-report tasksel tasksel-data
apt-get autoremove -y --purge

# Clean apt caches to reduce image size
echo "Cleaning apt caches..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Cleaned apt caches"

# Configure hostname
echo "Configuring hostname..."
echo "firewall" > /etc/hostname


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

# Set up root account (will be overridden by preseed in actual installation)
echo "root:root" | chpasswd

# Enable systemd as the init system
mkdir -p /etc/systemd/system/default.target.wants/

# Disable unnecessary systemd services
systemctl disable systemd-timesyncd.service || true
systemctl disable systemd-resolved.service || true
systemctl disable systemd-networkd.service || true

# Create a minimal fstab
cat > /etc/fstab << EOF
# /etc/fstab: static file system information
LABEL=root / ext4 defaults 0 1
EOF

# Set up locales for en_US.UTF-8
echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
rm -f /etc/locale.gen
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

# Set timezone to UTC
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "UTC" > /etc/timezone

# Create /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

echo "Chroot configuration complete."
