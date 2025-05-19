#!/bin/sh

set -eux

rootdir="$1"

# Create EFI partition
mkdir -p /output/efi
dd if=/dev/zero of=/output/efi/EFI.img bs=1M count=100
mkfs.vfat -F 32 /output/efi/EFI.img

# Mount EFI partition
mkdir -p "$rootdir/boot/efi"
mount /output/efi/EFI.img "$rootdir/boot/efi"


## Create essential files
#mkdir -p "$rootdir/bin"
#echo root:x:0:0:root:/root:/bin/sh > "$rootdir/etc/passwd"
#cat << END > "$rootdir/etc/group"
#root:x:0:
#mail:x:8:
#utmp:x:43:
#E