#!/bin/sh

set -eux

rootdir="$1"
#efi_mount_dir="/efimount"

rm -f "$rootdir/etc/resolv.conf"
rm -f "$rootdir/etc/hostname"

# === EFI partition ===
## # Create EFI filesystem
## mkdir -p /output
## dd if=/dev/zero of=/output/efi.img bs=1M count=50
## mkfs.vfat -F 32 /output/efi.img
## 
## # Mount EFI filesystem
## mkdir -p "$efi_mount_dir"
## mount -o loop /output/efi.img "$efi_mount_dir"

## # Copy EFI files
## rsync -a "${rootdir}/boot/EFI" "$efi_mount_dir"/EFI
## rsync -a "/config/boot/loader" "$efi_mount_dir"/loader
## rsync -a "${rootdir}/boot/systemd" "$efi_mount_dir"/systemd
## 
## # Unmount EFI filesystem
## umount "$efi_mount_dir"
## 

#echo "root:whistlekube" | chroot "$rootdir" chpasswd

# Install busybox to the target rootfs
#chroot "$rootdir" /bin/busybox --install -s
