#!/bin/bash

if [[ "${_WHISTLEKUBE_BOOT_INCLUDED:-}" != "yes" ]]; then
_WHISTLEKUBE_BOOT_INCLUDED=yes

# Function to check if the system is UEFI
is_uefi() {
    if [ -d "/sys/firmware/efi" ]; then
        return 0  # UEFI
    else
        return 1  # Legacy BIOS
    fi
}

# Build a minimal efi stub that just loads grub from the root partition
install_efi_stub() {
    local efi_mount="$1"
    local boot_uuid="$2"

    # Make sure arguments are set
    if [ -z "$efi_mount" ] || [ -z "$boot_uuid" ]; then
        echo "Error: install_efi_stub: Missing arguments"
        echo "Usage: install_efi_stub <efi_mount> <boot_uuid>"
        return 1
    fi

    local tmp_grub_cfg="/tmp/grub.cfg"
    cat <<EOF > ${tmp_grub_cfg}
search --fs-uuid --set=root ${boot_uuid}
set prefix=(\$root)/grub
configfile \${prefix}/grub.cfg
EOF
    # EFI partition contains a minimal grub that just loads the grub from the root partition
    mkdir -p "${efi_mount}/EFI/BOOT"
    grub-mkstandalone \
        -O x86_64-efi \
        -o "${efi_mount}/EFI/BOOT/BOOTX64.EFI" \
        --modules "normal configfile echo linux search search_fs_uuid part_msdos part_gpt fat ext2 efi_gop efi_uga" \
        --locales "" \
        --themes "" \
        "boot/grub/grub.cfg=${tmp_grub_cfg}"

    rm -f ${tmp_grub_cfg}
}

# Build a minimal efi stub that just loads grub from the root partition
install_systemd_boot() {
    local efi_mount="$1"
    local boot_uuid="$2"

    # Make sure arguments are set
    if [ -z "$efi_mount" ] || [ -z "$boot_uuid" ]; then
        echo "Error: install_systemd_boot: Missing arguments"
        echo "Usage: install_systemd_boot <efi_mount> <boot_uuid>"
        return 1
    fi

    # Install systemd-boot
    mkdir -p "${efi_mount}/EFI/systemd"
    cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi "${efi_mount}/EFI/systemd/systemd-bootx64.efi"
    mkdir -p "${efi_mount}/EFI/BOOT"
    cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi "${efi_mount}/EFI/BOOT/BOOTX64.EFI"
    mkdir -p "${efi_mount}/loader/entries"
    cat <<EOF > "${efi_mount}/loader/entries/whistlekube.conf"
title Whistlekube Linux
linux /EFI/Linux/vmlinuz
initrd /EFI/Linux/initrd.img
options root=live:UUID=${boot_uuid} rd.debug rd.live.debug rd.live.image console=tty0, console=ttyS0,115200
EOF

    # Copy the kernel and initrd to the EFI partition
    mkdir -p "${efi_mount}/EFI/Linux"
    cp /run/live/medium/boot/vmlinuz "${efi_mount}/EFI/Linux/vmlinuz"
    cp /run/live/medium/boot/initrd.img "${efi_mount}/EFI/Linux/initrd.img"
}

install_grub_cfg() {
    local boot_mount="$1"
    local boot_uuid="$2"

    # Make sure arguments are set
    if [ -z "$boot_mount" ] || [ -z "$boot_uuid" ]; then
        echo "Error: install_grub_cfg: Missing arguments"
        echo "Usage: install_grub_cfg <boot_mount> <boot_uuid>"
        return 1
    fi

    mkdir -p "${boot_mount}/grub"
    cat <<EOF > "${boot_mount}/grub/grub.cfg"
set timeout=5
set default="0"

setial --unit=0 --speed=115200
terminal --timeout=5 serial console

menuentry "Whistlekube Linux" {
    echo "Loading whistlekube kernel..."
    linux /slot_a/vmlinuz root=UUID=${boot_uuid} live-media-path=/slot_a persistence persistence-storage=filesystem \\
        nomodeset debug console=tty0, console=ttyS0,115200
        
    echo "Loading whistlekube initrd..."
    initrd /slot_a/initrd.img
}

menuentry "Whistlekube Linux (fallback)" {
    search --fs-uuid --set=root ${boot_uuid}
    echo "Loading whistlekube kernel..."
    linux /slot_b/vmlinuz boot=live components nomodeset debug live-media-path=/slot_b
    echo "Loading whistlekube initrd..."
    initrd /slot_b/initrd.img
}

menuentry "Whistlekube Linux (recovery mode)" {
    search --fs-uuid --set=root ${boot_uuid}
    echo "Loading kernel (recovery mode)..."
    linux /slot_a/vmlinuz boot=live components nomodeset live-media-path=/slot_a \
        noapic noapm nodma nomce nolapic \
        debug # Useful for troubleshooting live-boot
    echo "Loading initial ramdisk (recovery mode)..."
    initrd /slot_a/initrd.img
}
EOF
    
}

fi
