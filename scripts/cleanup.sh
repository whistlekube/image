#!/bin/bash
set -euo pipefail

# Takes a directory to clean up as an argument
WORK_DIR="${1:-/build/work}"

echo "Cleaning up build artifacts..."

# Unmount any remaining filesystems in chroot (if any)
if [ -d "${WORK_DIR}/chroot/proc" ]; then
    if mountpoint -q "${WORK_DIR}/chroot/proc"; then
        umount -l "${WORK_DIR}/chroot/proc" || true
    fi
fi

if [ -d "${WORK_DIR}/chroot/sys" ]; then
    if mountpoint -q "${WORK_DIR}/chroot/sys"; then
        umount -l "${WORK_DIR}/chroot/sys" || true
    fi
fi

if [ -d "${WORK_DIR}/chroot/dev" ]; then
    if mountpoint -q "${WORK_DIR}/chroot/dev/pts"; then
        umount -l "${WORK_DIR}/chroot/dev/pts" || true
    fi
    if mountpoint -q "${WORK_DIR}/chroot/dev"; then
        umount -l "${WORK_DIR}/chroot/dev" || true
    fi
fi

# Remove work directory
if [ -d "${WORK_DIR}" ]; then
    rm -rf "${WORK_DIR}"
fi

echo "Cleanup complete."
