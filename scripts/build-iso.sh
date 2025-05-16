#!/bin/bash
set -eauox pipefail

# Build variables
BUILD_VERSION=${BUILD_VERSION:-"$(date +%Y%m%d)"}
DEBIAN_RELEASE=${DEBIAN_RELEASE:-"trixie"}
DEBIAN_ARCH=${DEBIAN_ARCH:-"amd64"}
ISO_OUTPUT_FILE=${ISO_OUTPUT_FILE:-"whistlekube-installer-${DEBIAN_RELEASE}-${DEBIAN_ARCH}-${BUILD_VERSION}.iso"}
ISO_LABEL=${ISO_LABEL:-"WHISTLEKUBE_ISO"}
ISO_APPID=${ISO_APPID:-"Whistlekube Installer"}
ISO_PUBLISHER=${ISO_PUBLISHER:-"Whistlekube"}
ISO_PREPARER=${ISO_PREPARER:-"Built with xorriso"}

# Directories
ISO_DIR="${ISO_DIR:-$(pwd)/iso}"
EFI_MOUNT_POINT="${EFI_MOUNT_POINT:-/efimount}"
HYBRID_MBR_PATH="${HYBRID_MBR_PATH:-/usr/lib/grub/i386-pc/boot_hybrid.img}"


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

build_iso() {
  echo "Creating bootable ISO..."
  xorriso \
    -as mkisofs \
    -iso-level 3 \
    -rock --joliet --joliet-long \
    -full-iso9660-filenames \
    -volid "${ISO_LABEL}" \
    -appid "${ISO_APPID}" \
    -publisher "${ISO_PUBLISHER}" \
    -preparer "${ISO_PREPARER}" \
    -eltorito-boot boot/grub/core.img \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      --grub2-boot-info \
    -eltorito-alt-boot \
      -e EFI/efiboot.img \
      -no-emul-boot \
    -isohybrid-mbr ${HYBRID_MBR_PATH} \
    -append_partition 2 0xef "${ISO_DIR}/EFI/efiboot.img" \
    -isohybrid-gpt-basdat \
    -output "${ISO_OUTPUT_FILE}" \
    "${ISO_DIR}"
}

echo "======================================================"
echo "Building Whistlekube Installer ISO"
echo "======================================================"
echo "Build Version: ${BUILD_VERSION}"
echo "Debian Release: ${DEBIAN_RELEASE}"
echo "Architecture: ${DEBIAN_ARCH}"
echo "ISO dir: ${ISO_DIR}"
echo "======================================================"

# Create bootable ISO directory structure
mkdir -p "${ISO_DIR}"/{boot/{isolinux,grub},EFI/boot,install,preseed,live}

# Verify the files were copied correctly
if [ ! -f "${ISO_DIR}/live/vmlinuz" ] || \
   [ ! -f "${ISO_DIR}/live/initrd.img" ] || \
   [ ! -f "${ISO_DIR}/live/filesystem.squashfs" ]; then
    echo "Error: Live chroot files not found"
    exit 1
fi
if [ ! -f "${ISO_DIR}/installer/target.squashfs" ]; then
    echo "Error: Target chroot filesystem not found"
    exit 1
fi
if [ ! -f "${ISO_DIR}/boot/grub/grub.cfg" ]; then
    echo "Error: GRUB config not found"
    exit 1
fi

# Create GRUB for BIOS boot
echo "Creating GRUB for BIOS boot..."
build_grub_bios

# Create GRUB for UEFI boot
echo "Creating GRUB for UEFI boot..."
build_grub_uefi

# Create the ISO
echo "Creating the ISO..."
build_iso

# Calculate checksum
sha256sum "${ISO_OUTPUT_FILE}" > "${ISO_OUTPUT_FILE}.sha256"

echo "======================================================"
echo "Build complete!"
echo "ISO file: ${ISO_OUTPUT_FILE}"
echo "SHA256: $(cat ${ISO_OUTPUT_FILE}.sha256)"
echo "======================================================"

# Clean up
#/scripts/cleanup.sh "${WORK_DIR}"
