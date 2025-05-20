#!/bin/bash
set -euo pipefail

# Build variables
OUTPUT_DIR=${OUTPUT_DIR:-$(pwd)/output}
ISO_DIR="${ISO_DIR:-$(pwd)/cdrom}"
ISO_LABEL=${ISO_LABEL:-"WHISTLEKUBE_ISO"}
ISO_APPID=${ISO_APPID:-"Whistlekube Installer"}
ISO_PUBLISHER=${ISO_PUBLISHER:-"Whistlekube"}
ISO_PREPARER=${ISO_PREPARER:-"Built with xorriso"}
ISO_FILENAME=${ISO_FILENAME:-"whistlekube-installer.iso"}
ISO_OUTPUT_PATH="${OUTPUT_DIR}/${ISO_FILENAME}"
EFI_MOUNT_POINT="${EFI_MOUNT_POINT:-/efimount}"
HYBRID_MBR_PATH="${HYBRID_MBR_PATH:-/usr/lib/grub/i386-pc/boot_hybrid.img}"

# Build the GRUB core image for BIOS boot
# Writes the core.img to the ISO_DIR/boot/grub directory
build_grub_bios() {
  grub-mkimage \
    -O i386-pc-eltorito \
    -o "${ISO_DIR}/boot/grub/core.img" \
    -p /boot/grub \
    biosdisk iso9660 \
    normal configfile \
    echo linux search search_label \
    part_msdos part_gpt fat ext2
}

# Build the UEFI boot image
# Writes the efiboot.img to the ISO_DIR/EFI directory
build_grub_uefi() {
  mkdir -p "${ISO_DIR}/EFI" "${EFI_MOUNT_POINT}"
  dd if=/dev/zero of="${ISO_DIR}/EFI/efiboot.img" bs=1M count=10
  mkfs.vfat -F 32 "${ISO_DIR}/EFI/efiboot.img"
  mkdir -p "${EFI_MOUNT_POINT}"
  mount -o loop "${ISO_DIR}/EFI/efiboot.img" "${EFI_MOUNT_POINT}"
  mkdir -p "${EFI_MOUNT_POINT}/EFI/BOOT"
  grub-mkimage \
    -O x86_64-efi \
    -o "${EFI_MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI" \
    -p /boot/grub \
    iso9660 normal configfile \
    echo linux search search_label \
    part_msdos part_gpt fat ext2 efi_gop efi_uga \
    all_video font && \
  cp "${ISO_DIR}/boot/grub/grub.cfg" "${EFI_MOUNT_POINT}/EFI/BOOT/grub.cfg"
  umount "${EFI_MOUNT_POINT}"
  rmdir "${EFI_MOUNT_POINT}"
}

# Build the final ISO
# This is a hybrid ISO that can be booted from BIOS or UEFI and installed on a CD or USB drive
build_iso() {
  echo "Creating bootable ISO..."
  mkdir -p "${OUTPUT_DIR}"
  find "${ISO_DIR}"
  xorriso \
    -as mkisofs \
    -iso-level 3 \
    -rock --joliet --joliet-long \
    -full-iso9660-filenames \
    -volid "${ISO_LABEL}" \
    -appid "${ISO_APPID}" \
    -publisher "${ISO_PUBLISHER}" \
    -preparer "${ISO_PREPARER}" \
    -c boot.catalog \
    -eltorito-boot boot/grub/core.img \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
    -eltorito-alt-boot \
      -e boot/grub/efi.img \
      -no-emul-boot \
    -isohybrid-mbr ${HYBRID_MBR_PATH} \
    -isohybrid-gpt-basdat \
    -output "${ISO_OUTPUT_PATH}" \
    "${ISO_DIR}"
}

# Create bootable ISO directory structure
mkdir -p "${ISO_DIR}"/{boot/grub,EFI/boot,install,preseed,live}

# Verify the files were copied correctly
if [ ! -f "${ISO_DIR}/live/vmlinuz" ] || \
   [ ! -f "${ISO_DIR}/live/initrd.img" ] || \
   [ ! -f "${ISO_DIR}/live/filesystem.squashfs" ]; then
    echo "Error: Live chroot files not found"
    exit 1
fi
#if [ ! -f "${ISO_DIR}/install/filesystem.squashfs" ]; then
#    echo "Error: Target chroot filesystem not found"
#    exit 1
#fi
if [ ! -f "${ISO_DIR}/boot/grub/grub.cfg" ]; then
    echo "Error: GRUB config not found"
    exit 1
fi

# Create GRUB for BIOS boot
echo "Creating GRUB for BIOS boot..."
#build_grub_bios

# Create GRUB for UEFI boot
echo "Creating GRUB for UEFI boot..."
#build_grub_uefi

# Create the ISO
echo "Creating the ISO..."
find "${ISO_DIR}"
build_iso

# Calculate checksum
sha256sum "${ISO_OUTPUT_PATH}" > "${ISO_OUTPUT_PATH}.sha256"

# Create convenience symlinks
ln -s "${ISO_FILENAME}" "${OUTPUT_DIR}/whistlekube-installer.iso"
ln -s "${ISO_FILENAME}.sha256" "${OUTPUT_DIR}/whistlekube-installer.iso.sha256"

echo "======================================================"
echo "Build complete!"
echo "ISO file: ${ISO_OUTPUT_PATH}"
echo "SHA256: $(cat ${ISO_OUTPUT_PATH}.sha256)"
echo "======================================================"

# Clean up
#/scripts/cleanup.sh "${WORK_DIR}"
