#!/bin/bash

set -euo pipefail

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root!${NC}"
    exit 1
fi

WKINSTALL_MEDIUM_PATH=${WKINSTALL_MEDIUM_PATH:-/run/live/medium}
WKINSTALL_EFI_MNT=${WKINSTALL_EFI_MNT:-/mnt/wkinstall-efi}
WKINSTALL_BOOT_MNT=${WKINSTALL_BOOT_MNT:-/mnt/wkinstall-boot}
WKINSTALL_ROOT_MNT=${WKINSTALL_ROOT_MNT:-/mnt/wkinstall-root}
WKINSTALL_LIB_DIR=${WKINSTALL_LIB_DIR:-/usr/local/lib/wkinstall/lib}

source "${WKINSTALL_LIB_DIR}/partition.sh"
source "${WKINSTALL_LIB_DIR}/boot.sh"

disk="$1"

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

efi_part_dev=$(get_efi_partition "$disk")
boot_part_dev=$(get_boot_partition_efi "$disk")
root_part_dev=$(get_root_partition_efi "$disk")
boot_uuid=$(get_partition_uuid "$boot_part_dev")

mkdir -p "$WKINSTALL_EFI_MNT"
mkdir -p "$WKINSTALL_BOOT_MNT"
mkdir -p "$WKINSTALL_ROOT_MNT"

echo "=== Mounting EFI partition ==="
mount_efi_partition "$disk" "$WKINSTALL_EFI_MNT"

echo "=== Mounting boot partition ==="
mount_boot_partition "$disk" "$WKINSTALL_BOOT_MNT"

echo "=== Mounting root partition ==="
mount_root_partition "$disk" "$WKINSTALL_ROOT_MNT"

echo "=== Copying files to EFI partition ==="
install_efi_stub "$WKINSTALL_EFI_MNT" "$boot_uuid"

echo "=== Copying files to boot partition ==="
cp -a "${WKINSTALL_MEDIUM_PATH}/boot" "${WKINSTALL_BOOT_MNT}/slot_a"
cp -a "${WKINSTALL_MEDIUM_PATH}/boot" "${WKINSTALL_BOOT_MNT}/slot_b"
mkdir "${WKINSTALL_BOOT_MNT}/grub"
echo "current=a" >> "${WKINSTALL_BOOT_MNT}/grub/abstate.conf"
install_grub_cfg "${WKINSTALL_BOOT_MNT}" "${boot_uuid}"
cp -a "${WKINSTALL_MEDIUM_PATH}/install/filesystem.squashfs" "${WKINSTALL_BOOT_MNT}/slot_a/filesystem.squashfs"
cp -a "${WKINSTALL_MEDIUM_PATH}/install/filesystem.squashfs" "${WKINSTALL_BOOT_MNT}/slot_b/filesystem.squashfs"

echo "=== Copying files to root partition ==="
mkdir -p "$WKINSTALL_BOOT_MNT/overlay"

echo "=== EFI files ==="
find "$WKINSTALL_EFI_MNT"

echo "=== Boot files ==="
find "$WKINSTALL_BOOT_MNT"

echo "=== Root files ==="
find "$WKINSTALL_ROOT_MNT"


echo "=== Unmounting partitions ==="
sync
umount ${WKINSTALL_EFI_MNT}
umount ${WKINSTALL_BOOT_MNT}
umount ${WKINSTALL_ROOT_MNT}

