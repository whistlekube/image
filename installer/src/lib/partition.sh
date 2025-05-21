#!/bin/bash

if [[ "${_WHISTLEKUBE_PARTITION_INCLUDED:-}" != "yes" ]]; then
_WHISTLEKUBE_PARTITION_INCLUDED=yes

get_partition_by_number() {
    local device="$1"
    local part_num="$2"

    # Ensure parameters are set
    if [[ -z "$device" || -z "$part_num" ]]; then
        echo "Missing parameters"
        echo "Usage: get_partition_by_number <device> <part_num>"
        return 1
    fi
    local dev_name=$(basename "$device")
    local sys_path="/sys/block/${dev_name}"

    # Check if device exists
    if [ ! -b "$device" ] || [ ! -d "$sys_path" ]; then
        echo "Error: Device $device does not exist" >&2
        return 1
    fi

    # Find the partition with the specified number
    for part_dir in "$sys_path"/${dev_name}*; do
        # Check if this is actually a partition
        if [ -d "$part_dir" ] && [ -f "$part_dir/partition" ]; then
            local current_part_num=$(cat "$part_dir/partition")
            
            if [ "$current_part_num" -eq "$part_num" ]; then
                local part_name=$(basename "$part_dir")
                echo "/dev/$part_name"
                return 0
            fi
        fi
    done

    echo "Partition number $part_num not found on $device" >&2
    return 1
}

get_efi_partition() {
    get_partition_by_number "$1" 1
}

get_boot_partition_efi() {
    get_partition_by_number "$1" 2
}

get_root_partition_efi() {
    get_partition_by_number "$1" 3
}

get_boot_partition_mbr() {
    get_partition_by_number "$1" 1
}

get_partition_uuid() {
    local part_dev="$1"
    blkid -s UUID -o value "$part_dev"
}

partition_disk_efi() {
    local disk="$1"
    local esp_size_mb=512
    local boot_size_mb=2048

    local esp_end=$((${esp_size_mb} + 1))
    local boot_end=$((${esp_end} + ${boot_size_mb}))

    parted -s "$disk" mklabel gpt || echo "Warning: Failed to create GPT label on $disk"
    parted -s "$disk" mkpart primary fat32 1MiB $esp_end
    parted -s "$disk" set 1 esp on
    parted -s "$disk" mkpart primary ext4 $esp_end $boot_end
    parted -s "$disk" mkpart primary ext4 $boot_end 100%

    # Wait for udev to settle and recognize the new partitions
    sleep 1
    udevadm settle

    local efi_dev=$(get_efi_partition "$disk")
    local boot_dev=$(get_boot_partition_efi "$disk")
    local root_dev=$(get_root_partition_efi "$disk")

    # Format the partitions
    mkfs.fat -F32 "$efi_dev"
    echo "EFI partition formatted: $efi_dev"
    mkfs.ext4 -F "$boot_dev"
    echo "Boot partition formatted: $boot_dev"
    mkfs.ext4 -F "$root_dev"
    echo "Root partition formatted: $root_dev"
}

mount_efi_partition() {
    mount $(get_efi_partition "$1") "$2"
}

mount_boot_partition() {
    mount $(get_boot_partition_efi "$1") "$2"
}

mount_root_partition() {
    mount $(get_root_partition_efi "$1") "$2"
}


fi
