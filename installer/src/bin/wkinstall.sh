#!/bin/bash

set -euxo pipefail

WKINSTALL_KERNEL_PATH=${WKINSTALL_KERNEL_PATH:-/run/media/live/vmlinuz}
WKINSTALL_INITRD_PATH=${WKINSTALL_INITRD_PATH:-/run/media/live/initrd.img}
WKINSTALL_EFI_STUB_PATH=${WKINSTALL_EFI_STUB_PATH:-/run/media/live/efi.img}
WKINSTALL_EFI_CORE_PATH=${WKINSTALL_EFI_CORE_PATH:-/run/media/live/core.img}
WKINSTALL_EFI_MNT=${WKINSTALL_EFI_MNT:-/mnt/wkinstall-efi}
WKINSTALL_BOOT_MNT=${WKINSTALL_BOOT_MNT:-/mnt/wkinstall-boot}
WKINSTALL_ROOT_MNT=${WKINSTALL_ROOT_MNT:-/mnt/wkinstall-root}
LIB_DIR="lib"

source "${LIB_DIR}/partition.sh"

local disk="$1"

if [ -z "$disk" ]; then
    echo "Usage: $0 <disk>"
    exit 1
fi

if [ ! -b "$disk" ]; then
    echo "Error: Device $disk does not exist"
    exit 1
fi

## Ask for confirmation
#dialog --title "Confirm erase disk" --yesno "This will erase all data on $disk. Continue?" 8 60
#if [ $? -ne 0 ]; then
#    echo "Operation cancelled"
#    exit 1
#fi

echo "=== Partitioning disk $disk ==="
partition_disk_efi "$disk"

mkdir -p "$WHINSTALL_EFI_MNT"
mkdir -p "$WHINSTALL_BOOT_MNT"
mkdir -p "$WHINSTALL_ROOT_MNT"

echo "=== Mounting EFI partition ==="
mount_efi_partition "$disk" "$WHINSTALL_EFI_MNT"

echo "=== Mounting boot partition ==="
mount_boot_partition "$disk" "$WHINSTALL_BOOT_MNT"

echo "=== Mounting root partition ==="
mount_root_partition "$disk" "$WHINSTALL_ROOT_MNT"

echo "=== Copying files to EFI partition ==="
cp -r "$WKINSTALL_EFI_STUB_PATH" "$WHINSTALL_EFI_MNT"/EFI/BOOT/BOOTX64.EFI

echo "=== Copying files to boot partition ==="
cp -r /build/boot/* "$WHINSTALL_BOOT_MNT"

echo "=== Copying files to root partition ==="
cp -r /build/root/* "$WHINSTALL_ROOT_MNT"



