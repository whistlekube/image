#!/bin/sh

set -eux

rootdir="$1"

## # Create EFI partition
## mkdir -p /output
## dd if=/dev/zero of=/output/efi.img bs=1M count=500
## mkfs.vfat -F 32 /output/efi.img
## 
## # Mount EFI partition
## mkdir -p "$rootdir/boot"
## mount -o loop /output/efi.img "$rootdir/boot"

## Create essential files
#mkdir -p "$rootdir/bin"
echo root:x:0:0:root:/root:/bin/sh > "$rootdir/etc/passwd"
cat << END > "$rootdir/etc/group"
root:x:0:
mail:x:8:
utmp:x:43:
END
