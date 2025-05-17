#!/bin/sh

set -eux

rootdir="$1"

rm -f "$rootdir/etc/resolv.conf"
rm -f "$rootdir/etc/hostname"

# Install busybox to the target rootfs
#chroot "$rootdir" /bin/busybox --install -s
