#!/bin/bash

set -euxo pipefail

SYSTEMD_PACKAGES="systemd systemd-boot systemd-sysv"
LINUX_PACKAGES="linux-image-amd64"

# Configuration variables
DEBIAN_RELEASE=${DEBIAN_RELEASE:-trixie}
DEBIAN_MIRROR=${DEBIAN_MIRROR:-http://deb.debian.org/debian}
ROOTFS_DIR=${ROOTFS_DIR:-$PWD/rootfs}
MMDEBSTRAP_VARIANT=${MMDEBSTRAP_VARIANT:-essential}
MMDEBSTRAP_INCLUDE=${MMDEBSTRAP_INCLUDE:-"${SYSTEMD_PACKAGES} ${LINUX_PACKAGES}"}
MMDEBSTRAP_EXTRA_OPTIONS=${MMDEBSTRAP_EXTRA_OPTIONS:-}

# Debug mode
if [ "${WKINSTALL_DEBUG:-false}" = "true" ]; then
  MMDEBSTRAP_EXTRA_OPTIONS="${MMDEBSTRAP_EXTRA_OPTIONS} --verbose"
fi

# Create minimal Debian rootfs with mmdebstrap
echo "Creating rootfs with mmdebstrap..."
mmdebstrap \
  --variant=${MMDEBSTRAP_VARIANT} \
  --include="$MMDEBSTRAP_INCLUDE" \
  --components="main contrib non-free non-free-firmware" \
  --setup-hook='mkdir -p "$1/etc/apt/keyrings"' \
  --setup-hook='curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o "$1/etc/apt/keyrings/docker.gpg"' \
  --aptopt='APT::Sandbox::User "root"' \
  --aptopt='APT::Install-Recommends "false"' \
  --aptopt='APT::Install-Suggests "false"' \
  --aptopt='Acquire::Languages { "environment"; "en"; }' \
  --aptopt='Acquire::Languages "none"' \
  $MMDEBSTRAP_EXTRA_OPTIONS \
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
  "$DEBIAN_MIRROR" \
  "$@"

