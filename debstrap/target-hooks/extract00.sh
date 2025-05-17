#!/bin/sh

set -eux

rootdir="$1"

# Install busybox to the target rootfs
#chroot "$rootdir" /bin/busybox --install -s
