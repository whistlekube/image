#!/bin/bash
# This script runs within the target chroot environment and configures the base system
# It runs after the overlay files have been applied

set -euxo pipefail

# Source the functions
source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

# Mount filesystems
mount_filesystems

# Cleanup
cleanup_apt
cleanup_boot

# Unmount filesystems
unmount_filesystems
