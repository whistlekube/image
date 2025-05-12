#!/bin/bash
set -euo pipefail

# Default values (can be overridden by environment variables)
BUILD_VERSION=${BUILD_VERSION:-"$(date +%Y%m%d)"}
ISO_FILENAME=${ISO_FILENAME:-"whistlekube-installer.iso"}
DEBIAN_RELEASE=${DEBIAN_RELEASE:-"trixie"}
DEBIAN_ARCH=${DEBIAN_ARCH:-"amd64"}
DEBIAN_MIRROR=${DEBIAN_MIRROR:-"http://deb.debian.org/debian"}

# Directories
WORK_DIR="/build/work"
CHROOT_DIR="${WORK_DIR}/chroot"
ISO_DIR="${WORK_DIR}/iso"
OUTPUT_DIR="/output"

# Ensure clean build environment
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}" "${CHROOT_DIR}" "${ISO_DIR}" "${OUTPUT_DIR}"

echo "======================================================"
echo "Building Whistlekube Installer ISO"
echo "======================================================"
echo "Build Version: ${BUILD_VERSION}"
echo "Debian Release: ${DEBIAN_RELEASE}"
echo "Architecture: ${DEBIAN_ARCH}"
echo "Mirror: ${DEBIAN_MIRROR}"
echo "Output Filename: ${ISO_FILENAME}"
echo "======================================================"

# Step 1: Create minimal Debian system with debootstrap
echo "[1/5] Running debootstrap to create minimal Debian system..."
debootstrap --arch="${DEBIAN_ARCH}" \
            --variant=minbase \
            --include=systemd,systemd-sysv \
            "${DEBIAN_RELEASE}" \
            "${CHROOT_DIR}" \
            "${DEBIAN_MIRROR}"

# Step 2: Configure chroot environment
echo "[2/5] Configuring chroot environment..."
cp /config/packages.list "${CHROOT_DIR}/packages.list"
cp /scripts/configure-chroot.sh "${CHROOT_DIR}/configure-chroot.sh"
chmod +x "${CHROOT_DIR}/configure-chroot.sh"

# Mount essential filesystems for chroot
mount -t proc proc "${CHROOT_DIR}/proc"
mount -t sysfs sysfs "${CHROOT_DIR}/sys"
mount --bind /dev "${CHROOT_DIR}/dev"
mount --bind /dev/pts "${CHROOT_DIR}/dev/pts" || mkdir -p "${CHROOT_DIR}/dev/pts" && mount --bind /dev/pts "${CHROOT_DIR}/dev/pts"

# Copy DNS resolver settings
cp /etc/resolv.conf "${CHROOT_DIR}/etc/resolv.conf"

# Make sure /dev/shm is properly set up for systemd
if [ ! -d "${CHROOT_DIR}/dev/shm" ]; then mkdir -p "${CHROOT_DIR}/dev/shm"; fi
mount -t tmpfs shm "${CHROOT_DIR}/dev/shm"

# Execute the configuration script inside the chroot
DEBIAN_FRONTEND=noninteractive chroot "${CHROOT_DIR}" /configure-chroot.sh

# Unmount chroot file systems
umount -l "${CHROOT_DIR}/dev/shm" || true
umount -l "${CHROOT_DIR}/dev/pts" || true
umount -l "${CHROOT_DIR}/dev" || true
umount -l "${CHROOT_DIR}/sys" || true
umount -l "${CHROOT_DIR}/proc" || true

# Step 3: Create bootable ISO structure
echo "[3/5] Creating bootable ISO structure..."
mkdir -p "${ISO_DIR}/boot/isolinux"
mkdir -p "${ISO_DIR}/boot/grub/x86_64-efi"
mkdir -p "${ISO_DIR}/EFI/boot"
mkdir -p "${ISO_DIR}/install"
mkdir -p "${ISO_DIR}/preseed"

# Copy kernel and initrd from chroot
cp "${CHROOT_DIR}/boot/vmlinuz-"* "${ISO_DIR}/boot/vmlinuz"
cp "${CHROOT_DIR}/boot/initrd.img-"* "${ISO_DIR}/boot/initrd.img"

# Copy isolinux files
cp /usr/lib/ISOLINUX/isolinux.bin "${ISO_DIR}/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "${ISO_DIR}/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/libcom32.c32 "${ISO_DIR}/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/libutil.c32 "${ISO_DIR}/boot/isolinux/"
cp /usr/lib/syslinux/modules/bios/menu.c32 "${ISO_DIR}/boot/isolinux/"

# Create isolinux.cfg
cat > "${ISO_DIR}/boot/isolinux/isolinux.cfg" << EOF
UI menu.c32
PROMPT 0
TIMEOUT 30
DEFAULT install

LABEL install
  MENU LABEL Install Whistlekube
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.img auto=true priority=critical preseed/file=/preseed/preseed.cfg quiet
EOF

# Create UEFI boot support
echo "Creating UEFI boot support..."

# Create GRUB configuration
cat > "${ISO_DIR}/boot/grub/grub.cfg" << EOF
set timeout=30
set default=0

menuentry "Install Debian Minimal" {
    linux /boot/vmlinuz auto=true priority=critical preseed/file=/preseed/preseed.cfg quiet
    initrd /boot/initrd.img
}
EOF

# Create a temporary directory for the UEFI image
UEFI_TMP=$(mktemp -d)
truncate -s 4M "${UEFI_TMP}/efi.img"
mkfs.vfat "${UEFI_TMP}/efi.img"

mkdir -p "${UEFI_TMP}/mnt"
mount "${UEFI_TMP}/efi.img" "${UEFI_TMP}/mnt"

mkdir -p "${UEFI_TMP}/mnt/EFI/boot"
cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "${UEFI_TMP}/mnt/EFI/boot/bootx64.efi" || \
cp /usr/lib/grub/x86_64-efi/grubx64.efi "${UEFI_TMP}/mnt/EFI/boot/bootx64.efi"

mkdir -p "${UEFI_TMP}/mnt/boot/grub"
cp "${ISO_DIR}/boot/grub/grub.cfg" "${UEFI_TMP}/mnt/boot/grub/"

umount "${UEFI_TMP}/mnt"
cp "${UEFI_TMP}/efi.img" "${ISO_DIR}/boot/grub/"

# Clean up
rm -rf "${UEFI_TMP}"

# Also copy the UEFI bootloader to the standard location
mkdir -p "${ISO_DIR}/EFI/boot"
cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "${ISO_DIR}/EFI/boot/bootx64.efi" 2>/dev/null || \
cp /usr/lib/grub/x86_64-efi/grubx64.efi "${ISO_DIR}/EFI/boot/bootx64.efi"

# Copy preseed file
cp /config/preseed.cfg "${ISO_DIR}/preseed/"

# Step 4: Create squashfs of the chroot
echo "[4/5] Creating squashfs of the chroot..."
mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/install/filesystem.squashfs" -comp xz -wildcards

# Step 5: Generate the ISO
echo "[5/5] Generating the ISO..."
xorriso -as mkisofs \
    -r -J -joliet-long \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -partition_offset 16 \
    -A "Whistlekube ${BUILD_VERSION}" \
    -b boot/isolinux/isolinux.bin \
    -c boot/isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "${OUTPUT_DIR}/${ISO_FILENAME}" \
    "${ISO_DIR}"

# Make the image hybrid
echo "Making the ISO bootable on USB drives..."
isohybrid --uefi "${OUTPUT_DIR}/${ISO_FILENAME}" || echo "Warning: isohybrid command failed, USB boot may not work properly."

# Calculate checksum
cd "${OUTPUT_DIR}"
sha256sum "${ISO_FILENAME}" > "${ISO_FILENAME}.sha256"

echo "======================================================"
echo "Build complete!"
echo "ISO file: ${OUTPUT_DIR}/${ISO_FILENAME}"
echo "SHA256: $(cat ${OUTPUT_DIR}/${ISO_FILENAME}.sha256)"
echo "======================================================"

# Clean up
/scripts/cleanup.sh "${WORK_DIR}"
