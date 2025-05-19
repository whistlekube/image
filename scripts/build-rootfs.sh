#!/bin/bash

set -euxo pipefail

SYSTEMD_PACKAGES="systemd systemd-boot systemd-sysv"
LINUX_PACKAGES="linux-image-amd64"

# Configuration variables
DEBIAN_RELEASE=${DEBIAN_RELEASE:-trixie}
ROOTFS_DIR=${ROOTFS_DIR:-$PWD/rootfs}
MMDEBSTRAP_VARIANT=${MMDEBSTRAP_VARIANT:-apt}
MMDEBSTRAP_INCLUDE=${MMDEBSTRAP_INCLUDE:-"${SYSTEMD_PACKAGES} ${LINUX_PACKAGES}"}
EXTRA_APT_OPTIONS=${EXTRA_APT_OPTIONS:-}
HOOK_DIR=${HOOK_DIR:-/hooks}

# Create minimal Debian rootfs with mmdebstrap
echo "Creating rootfs with mmdebstrap..."
mmdebstrap \
  --verbose \
  --variant=${MMDEBSTRAP_VARIANT} \
  --include="$MMDEBSTRAP_INCLUDE" \
  --components="main contrib non-free non-free-firmware" \
  --aptopt='APT::Sandbox::User "root"' \
  --aptopt='APT::Install-Recommends "false"' \
  --aptopt='APT::Install-Suggests "false"' \
  --aptopt='Acquire::Languages { "environment"; "en"; }' \
  --aptopt='Acquire::Languages "none"' \
  $EXTRA_APT_OPTIONS \
  --dpkgopt=path-exclude=/usr/share/man/* \
  --dpkgopt=path-exclude=/usr/share/bug/* \
  --dpkgopt=path-exclude=/usr/share/info/* \
  --dpkgopt=path-exclude=/usr/share/locale/* \
  --dpkgopt=path-include=/usr/share/locale/locale.alias \
  --dpkgopt=path-exclude=/usr/share/bash-completion/* \
  --dpkgopt=path-exclude=/usr/share/doc/* \
  --dpkgopt=path-include=/usr/share/doc/*/copyright \
  --dpkgopt=path-exclude=/usr/share/fish/* \
  --dpkgopt=path-exclude=/usr/share/zsh/* \
  "$DEBIAN_RELEASE" \
  $ROOTFS_DIR \
  "https://deb.debian.org/debian"



#  --hook-dir=${HOOK_DIR} \




## # Make necessary modifications to rootfs for immutable design
## echo "Configuring rootfs for immutability..."
## 
## # Create bind mount points and RAM overlay configuration
## cat > /build/rootfs/etc/fstab << EOF
## # Static file system information for immutable setup
## tmpfs           /tmp            tmpfs   defaults,nosuid,nodev 0 0
## tmpfs           /var/tmp        tmpfs   defaults,nosuid,nodev 0 0
## tmpfs           /var/log        tmpfs   defaults 0 0
## tmpfs           /var/cache      tmpfs   defaults 0 0
## tmpfs           /var/lib/systemd  tmpfs   defaults 0 0
## tmpfs           /home           tmpfs   defaults 0 0
## EOF
## 
## # Create necessary overlay directories
## mkdir -p /build/rootfs/var/lib/overlay
## mkdir -p /build/rootfs/etc/tmpfiles.d
## 
## # Generate systemd-tmpfiles configuration for runtime directories
## cat > /build/rootfs/etc/tmpfiles.d/immutable.conf << EOF
## # Create runtime directories at boot
## d /var/log 0755 root root
## d /var/cache 0755 root root
## d /var/tmp 0755 root root
## d /var/lib/systemd 0755 root root
## d /home 0755 root root
## EOF
## 
## # Create service that runs at startup to set up overlays
## mkdir -p /build/rootfs/etc/systemd/system
## cat > /build/rootfs/etc/systemd/system/immuta-setup.service << EOF
## [Unit]
## Description=Set up RAM overlays for immutable system
## DefaultDependencies=no
## After=local-fs.target
## Before=sysinit.target
## 
## [Service]
## Type=oneshot
## ExecStart=/usr/local/bin/setup-overlays.sh
## RemainAfterExit=yes
## 
## [Install]
## WantedBy=sysinit.target
## EOF
## 
## # Create the setup-overlays script
## mkdir -p /build/rootfs/usr/local/bin
## cat > /build/rootfs/usr/local/bin/setup-overlays.sh << EOF
## #!/bin/sh
## # Setup RAM overlays for runtime modifications
## 
## # Mount points are already set in fstab, this script can be extended
## # for additional runtime configuration
## 
## # Enable persistent logging if needed
## if [ -d /var/lib/overlay/var-log ]; then
##   cp -a /var/lib/overlay/var-log/* /var/log/
## fi
## 
## exit 0
## EOF
## 
## chmod +x /build/rootfs/usr/local/bin/setup-overlays.sh
## 
## # Enable required services
## chroot /build/rootfs systemctl enable immuta-setup.service
## 
## # Disable networking components
## mkdir -p /build/rootfs/etc/systemd/system/network.target.wants
## touch /build/rootfs/etc/systemd/system/disable-network.service
## cat > /build/rootfs/etc/systemd/system/disable-network.service << EOF
## [Unit]
## Description=Disable all networking
## DefaultDependencies=no
## Before=sysinit.target
## 
## [Service]
## Type=oneshot
## ExecStart=/bin/sh -c "echo 'Networking disabled'"
## RemainAfterExit=yes
## 
## [Install]
## WantedBy=sysinit.target
## EOF
## 
## chroot /build/rootfs systemctl enable disable-network.service
## chroot /build/rootfs systemctl mask systemd-networkd.service
## chroot /build/rootfs systemctl mask systemd-resolved.service
## 
## # Set hostname
## echo "immutadebian" > /build/rootfs/etc/hostname
## 
## # Create a default user (optional, remove if not needed)
## chroot /build/rootfs useradd -m -s /bin/bash user
## chroot /build/rootfs usermod -aG sudo user
## echo "user:password" | chroot /build/rootfs chpasswd
## 
## echo "Rootfs preparation complete!"