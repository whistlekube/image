#!/bin/bash

set -euxo pipefail

BUILD_DIR=${BUILD_DIR:-/build}
QEMU_IMAGE_PREFIX=${QEMU_IMAGE_PREFIX:-disk}
OUTPUT_DIR=${OUTPUT_DIR:-/output}
NBD_DEVICE=${NBD_DEVICE:-/dev/nbd0}

# Disconnect the NBD device if it is already connected
qemu-nbd --disconnect ${NBD_DEVICE} || true

# Connect the NBD device to the image file
qemu-nbd --connect=${NBD_DEVICE} "${BUILD_DIR}/${QEMU_IMAGE_PREFIX}.qcow2"
sleep 1
lsblk

# Run the installer
/usr/local/sbin/wkinstall.sh ${NBD_DEVICE}

# Disconnect the NBD device
qemu-nbd --disconnect ${NBD_DEVICE} || true

# Copy the image to the output directory
mkdir -p ${OUTPUT_DIR}
cp "${BUILD_DIR}/${QEMU_IMAGE_PREFIX}.qcow2" ${OUTPUT_DIR}/
