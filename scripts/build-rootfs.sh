#!/bin/bash

set -euxo pipefail

SYSTEMD_PACKAGES="systemd systemd-boot systemd-sysv"
LINUX_PACKAGES="linux-image-amd64"

# Configuration variables
DEBIAN_RELEASE=${DEBIAN_RELEASE:-trixie}
ROOTFS_DIR=${ROOTFS_DIR:-$PWD/rootfs}
MMDEBSTRAP_VARIANT=${MMDEBSTRAP_VARIANT:-essential}
MMDEBSTRAP_INCLUDE=${MMDEBSTRAP_INCLUDE:-"${SYSTEMD_PACKAGES} ${LINUX_PACKAGES}"}
EXTRA_APT_OPTIONS=${EXTRA_APT_OPTIONS:-}

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

