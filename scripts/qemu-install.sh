#!/bin/bash

set -euxo pipefail

QCOW_FILE=${QCOW_FILE:-$1}
OUTPUT_DIR=${OUTPUT_DIR:-/output}
NBD_DEVICE=${NBD_DEVICE:-/dev/nbd0}

# Disconnect the NBD device if it is already connected
qemu-nbd --disconnect ${NBD_DEVICE} || true

# Connect the NBD device to the image file
qemu-nbd --connect=${NBD_DEVICE} "${QCOW_FILE}"
sleep 1
lsblk

# Run the installer
/usr/local/sbin/wkinstall.sh ${NBD_DEVICE}

# Disconnect the NBD device
qemu-nbd --disconnect ${NBD_DEVICE} || true
