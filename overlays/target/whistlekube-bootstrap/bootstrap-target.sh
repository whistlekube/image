#!/bin/bash

# This script runs within the target chroot environment and configures the system
# It runs after the overlay files have been applied

set -euxo pipefail

# Source the functions
source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

# Mount filesystems
mount_filesystems

export DEBIAN_FRONTEND=noninteractive

# Install packages specific to the target environment
apt-get update
apt-get install -y --no-install-recommends \
    grub-common

# Unmount filesystems
unmount_filesystems
