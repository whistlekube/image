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

# Execute the configuration script inside the chroot
chroot "${CHROOT_DIR}" /configure-chroot.sh

# Step 3: Create bootable ISO structure
echo "[3/5] Creating bootable ISO structure..."
mkdir -p "${ISO_DIR}/boot/isolinux"
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
  MENU LABEL Install Debian Minimal
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.img auto=true priority=critical preseed/file=/preseed/preseed.cfg quiet
EOF

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
    -A "Debian Minimal ${BUILD_VERSION}" \
    -b boot/isolinux/isolinux.bin \
    -c boot/isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -o "${OUTPUT_DIR}/${ISO_FILENAME}" \
    "${ISO_DIR}"

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
