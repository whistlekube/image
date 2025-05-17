#!/bin/sh

set -eux

rootdir="$1"

# Rsync the overlay files to the target rootfs
rsync -a /overlay/ "$rootdir/"

# Install busybox to the target rootfs
#chroot "$rootdir" /bin/busybox --install -s
