#!/bin/sh

set -eux

rootdir="$1"

rm -f "$rootdir/etc/resolv.conf"
rm -f "$rootdir/etc/hostname"
