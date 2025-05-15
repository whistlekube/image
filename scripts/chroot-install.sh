#!/bin/bash
set -eauox pipefail

# This script runs within the chroot environment and does common setup tasks

CHROOT_INSTALLER_DIR="${CHROOT_INSTALLER_DIR:-/whistlekube-chroot-installer}"

# Make sure we don't get prompted
export DEBIAN_FRONTEND=noninteractive

export OUTPUT_DIR=${OUTPUT_DIR:-/output}

# If the preinstall.sh script exists, run it
if [ -f "${CHROOT_INSTALLER_DIR}/layer/preinstall.sh" ]; then
    echo "Running preinstall.sh..."
    "${CHROOT_INSTALLER_DIR}/layer/preinstall.sh"
fi

# Install only the packages we need
echo "Installing packages..."
xargs apt-get install -y --no-install-recommends < "${CHROOT_INSTALLER_DIR}/layer/packages.list"

# Apply overlay
if [ -d "${CHROOT_INSTALLER_DIR}/layer/overlay" ]; then
    echo "Applying overlay..."
    cp -a "${CHROOT_INSTALLER_DIR}/layer/overlay"/* /
fi

# If the postinstall.sh script exists, run it
if [ -f "${CHROOT_INSTALLER_DIR}/layer/postinstall.sh" ]; then
    echo "Running postinstall.sh..."
    "${CHROOT_INSTALLER_DIR}/layer/postinstall.sh"
fi

echo "Common setup done"
