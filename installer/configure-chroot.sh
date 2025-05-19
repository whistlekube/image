#!/bin/bash

# This script is used to configure the chroot environment
# It is called by the Dockerfile when building the installer rootfs
# and is run within the chroot environment

set -euxo pipefail

systemctl enable whistlekube-installer.service

