#!/bin/bash
set -euo pipefail

# Default values (can be overridden by environment variables)
BUILD_VERSION=${BUILD_VERSION:-"$(date +%Y%m%d)"}
ISO_FILENAME=${ISO_FILENAME:-"whistlekube-installer.iso"}
DEBIAN_RELEASE=${DEBIAN_RELEASE:-"trixie"}
DEBIAN_ARCH=${DEBIAN_ARCH:-"amd64"}

# Directories
WORK_DIR="/build"
CHROOT_DIR="${WORK_DIR}/chroot"
ISO_DIR="${WORK_DIR}/iso"
OUTPUT_DIR="/output"

mkdir -p "${OUTPUT_DIR}"

echo "======================================================"
echo "Building Whistlekube Installer ISO"
echo "======================================================"
echo "Build Version: ${BUILD_VERSION}"
echo "Debian Release: ${DEBIAN_RELEASE}"
echo "Architecture: ${DEBIAN_ARCH}"
echo "Output Filename: ${ISO_FILENAME}"
echo "======================================================"

# Step 1: Configure chroot environment
echo "[1/4] Configuring chroot environment..."
# Mount essential filesystems for chroot
mkdir -p "${CHROOT_DIR}/proc"
mkdir -p "${CHROOT_DIR}/sys"
mkdir -p "${CHROOT_DIR}/dev"
mkdir -p "${CHROOT_DIR}/dev/pts"
mount -t proc proc "${CHROOT_DIR}/proc"
mount -t sysfs sysfs "${CHROOT_DIR}/sys"
mount --bind /dev "${CHROOT_DIR}/dev"
mount --bind /dev/pts "${CHROOT_DIR}/dev/pts"

cp /config/packages.list "${CHROOT_DIR}/packages.list"
cp /scripts/configure-chroot.sh "${CHROOT_DIR}/configure-chroot.sh"
chmod +x "${CHROOT_DIR}/configure-chroot.sh"

# Copy DNS resolver settings
mkdir -p "${CHROOT_DIR}/etc"
cp /etc/resolv.conf "${CHROOT_DIR}/etc/resolv.conf"

# Make sure /dev/shm is properly set up for systemd
if [ ! -d "${CHROOT_DIR}/dev/shm" ]; then mkdir -p "${CHROOT_DIR}/dev/shm"; fi
mount -t tmpfs shm "${CHROOT_DIR}/dev/shm"

# Execute the configuration script inside the chroot
DEBIAN_FRONTEND=noninteractive chroot "${CHROOT_DIR}" /bin/bash /configure-chroot.sh

# Unmount chroot file systems
umount -l "${CHROOT_DIR}/dev/shm" || true
umount -l "${CHROOT_DIR}/dev/pts" || true
umount -l "${CHROOT_DIR}/dev" || true
umount -l "${CHROOT_DIR}/sys" || true
umount -l "${CHROOT_DIR}/proc" || true


# Step 2: Create bootable ISO structure
echo "[2/4] Creating bootable ISO structure..."
mkdir -p "${ISO_DIR}"/{boot/{isolinux,grub},EFI/boot,install,preseed,live}

# Copy kernel and initrd from chroot
echo "Copying kernel and initrd files..."
KERNEL_FILE=$(ls -1 "${CHROOT_DIR}/boot/vmlinuz-"* 2>/dev/null | head -n 1)
INITRD_FILE=$(ls -1 "${CHROOT_DIR}/boot/initrd.img-"* 2>/dev/null | head -n 1)

if [ -z "$KERNEL_FILE" ] || [ -z "$INITRD_FILE" ]; then
    echo "Error: Could not find kernel or initrd files in ${CHROOT_DIR}/boot/"
    ls -la "${CHROOT_DIR}/boot/"
    exit 1
fi

echo "Found kernel: $KERNEL_FILE"
echo "Found initrd: $INITRD_FILE"

cp "$KERNEL_FILE" "${ISO_DIR}/boot/vmlinuz"
cp "$INITRD_FILE" "${ISO_DIR}/boot/initrd.img"

# Verify the files were copied correctly
if [ ! -f "${ISO_DIR}/boot/vmlinuz" ] || [ ! -f "${ISO_DIR}/boot/initrd.img" ]; then
    echo "Error: Failed to copy kernel or initrd files to ISO directory"
    exit 1
fi

echo "Kernel and initrd files copied successfully"

# Copy isolinux files
#cp /usr/lib/ISOLINUX/isolinux.bin "${ISO_DIR}/boot/isolinux/"
#cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "${ISO_DIR}/boot/isolinux/"
#cp /usr/lib/syslinux/modules/bios/libcom32.c32 "${ISO_DIR}/boot/isolinux/"
#cp /usr/lib/syslinux/modules/bios/libutil.c32 "${ISO_DIR}/boot/isolinux/"
#cp /usr/lib/syslinux/modules/bios/menu.c32 "${ISO_DIR}/boot/isolinux/"

# Copy isolinux files for BIOS boot
echo "Setting up BIOS boot..."
cp /usr/lib/ISOLINUX/isolinux.bin "${ISO_DIR}/boot/isolinux/"
cp /usr/lib/ISOLINUX/isohdpfx.bin "${WORK_DIR}/isohdpfx.bin"
cp /usr/lib/syslinux/modules/bios/{ldlinux.c32,libcom32.c32,libutil.c32,menu.c32,vesamenu.c32} "${ISO_DIR}/boot/isolinux/"


# Create isolinux.cfg
cat > "${ISO_DIR}/boot/isolinux/isolinux.cfg" << EOF
UI vesamenu.c32
PROMPT 0
TIMEOUT 30
DEFAULT install

LABEL install
  MENU LABEL ^Install Whistlekube
  MENU DEFAULT
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.img root=/dev/ram auto=true priority=critical preseed/file=/preseed/preseed.cfg quiet
EOF

# Create UEFI boot support
echo "Creating UEFI boot support..."

mkdir -p "${WORK_DIR}/efi-image/EFI/boot"

# Create GRUB configuration
mkdir -p "${ISO_DIR}/boot/grub"
cat > "${ISO_DIR}/boot/grub/grub.cfg" << EOF
set timeout=30
set default=0

menuentry "Install Whistlekube" {
    linux /boot/vmlinuz root=/dev/ram auto=true priority=critical preseed/file=/preseed/preseed.cfg quiet
    initrd /boot/initrd.img
}

menuentry "Boot from next volume" {
    exit 1
}

menuentry "UEFI Firmware Settings" {
    fwsetup
}
EOF

# Create startup.nsh for UEFI shell
echo "\\EFI\\boot\\bootx64.efi" > "${ISO_DIR}/startup.nsh"

# Create GRUB EFI bootloader
echo "Creating GRUB UEFI bootloader..."
grub-mkstandalone \
    --compress=xz \
    --modules="part_gpt part_msdos" \
    --format=x86_64-efi \
    --output="${ISO_DIR}/EFI/boot/bootx64.efi" \
    --locales="" \
    --fonts="" \
    --themes="" \
    "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg"

# Create a second copy for the image
cp "${ISO_DIR}/EFI/boot/bootx64.efi" "${WORK_DIR}/bootx64.efi"

# Create a FAT EFI system partition image
echo "Creating EFI system partition image..."
dd if=/dev/zero of="${WORK_DIR}/efi.img" bs=1M count=4
mkfs.vfat "${WORK_DIR}/efi.img"

# Mount the EFI image and copy the bootloader
mkdir -p "${WORK_DIR}/mnt"
mount "${WORK_DIR}/efi.img" "${WORK_DIR}/mnt" || {
    echo "Error mounting EFI image. Using alternative method..."
    # If mounting fails, use mtools instead
    mmd -i "${WORK_DIR}/efi.img" ::/EFI
    mmd -i "${WORK_DIR}/efi.img" ::/EFI/boot
    mcopy -i "${WORK_DIR}/efi.img" "${WORK_DIR}/bootx64.efi" ::/EFI/boot/
}

# Unmount if we mounted successfully
if mountpoint -q "${WORK_DIR}/mnt"; then
    mkdir -p "${WORK_DIR}/mnt/EFI/boot"
    cp "${WORK_DIR}/bootx64.efi" "${WORK_DIR}/mnt/EFI/boot/"
    umount "${WORK_DIR}/mnt"
fi

# Copy the EFI image
cp "${WORK_DIR}/efi.img" "${ISO_DIR}/boot/grub/efi.img"

# Add the Debian archives keyring
mkdir -p "${ISO_DIR}/keyring"
cp "${CHROOT_DIR}/usr/share/keyrings/debian-archive-keyring.gpg" "${ISO_DIR}/keyring/" 2>/dev/null || true


## # Create EFI directory structure directly
## mkdir -p "${ISO_DIR}/EFI/boot"
## 
## # Copy GRUB EFI binary to the standard location
## if [ -f /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi ]; then
##     cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "${ISO_DIR}/EFI/boot/bootx64.efi"
## elif [ -f /usr/lib/grub/x86_64-efi/grubx64.efi ]; then
##     cp /usr/lib/grub/x86_64-efi/grubx64.efi "${ISO_DIR}/EFI/boot/bootx64.efi"
## else
##     # Generate grub EFI file
##     echo "Generating GRUB EFI binary..."
##     grub-mkstandalone \
##         --format=x86_64-efi \
##         --output="${ISO_DIR}/EFI/boot/bootx64.efi" \
##         --locales="" \
##         --fonts="" \
##         "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg"
## fi
## 
## # Create a startup.nsh for UEFI shells
## echo "\\EFI\\boot\\bootx64.efi" > "${ISO_DIR}/startup.nsh"
## 
## # Create dummy efi.img file (not mounted, just a placeholder for xorriso)
## mkdir -p "${ISO_DIR}/boot/grub"
## touch "${ISO_DIR}/boot/grub/efi.img"

## # Create GRUB configuration
## cat > "${ISO_DIR}/boot/grub/grub.cfg" << EOF
## set timeout=30
## set default=0
## 
## menuentry "Install Debian Minimal" {
##     linux /boot/vmlinuz auto=true priority=critical preseed/file=/preseed/preseed.cfg quiet
##     initrd /boot/initrd.img
## }
## EOF
## 
## # Create a temporary directory for the UEFI image
## UEFI_TMP=$(mktemp -d)
## truncate -s 4M "${UEFI_TMP}/efi.img"
## mkfs.vfat "${UEFI_TMP}/efi.img"
## 
## mkdir -p "${UEFI_TMP}/mnt"
## mount "${UEFI_TMP}/efi.img" "${UEFI_TMP}/mnt"
## 
## mkdir -p "${UEFI_TMP}/mnt/EFI/boot"
## cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "${UEFI_TMP}/mnt/EFI/boot/bootx64.efi" || \
## cp /usr/lib/grub/x86_64-efi/grubx64.efi "${UEFI_TMP}/mnt/EFI/boot/bootx64.efi"
## 
## mkdir -p "${UEFI_TMP}/mnt/boot/grub"
## cp "${ISO_DIR}/boot/grub/grub.cfg" "${UEFI_TMP}/mnt/boot/grub/"
## 
## umount "${UEFI_TMP}/mnt"
## cp "${UEFI_TMP}/efi.img" "${ISO_DIR}/boot/grub/"
## 
## # Clean up
## rm -rf "${UEFI_TMP}"
## 
## # Also copy the UEFI bootloader to the standard location
## mkdir -p "${ISO_DIR}/EFI/boot"
## cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "${ISO_DIR}/EFI/boot/bootx64.efi" 2>/dev/null || \
## cp /usr/lib/grub/x86_64-efi/grubx64.efi "${ISO_DIR}/EFI/boot/bootx64.efi"

# Copy preseed file
cp /config/preseed.cfg "${ISO_DIR}/preseed/"

# Step 4: Create squashfs of the chroot
echo "[3/4] Creating squashfs of the chroot..."
mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/install/filesystem.squashfs" -comp xz -wildcards

# Step 5: Generate the ISO
echo "[4/4] Generating the ISO..."

# Basic options
XORRISO_OPTS="-as mkisofs -r -J -joliet-long"

# Volume ID and publisher
XORRISO_OPTS+=" -V 'WHISTLEKUBE_INSTALLER'"
XORRISO_OPTS+=" -publisher 'Whistlekube'"

# BIOS boot options
XORRISO_OPTS+=" -isohybrid-mbr ${WORK_DIR}/isohdpfx.bin"
XORRISO_OPTS+=" -b boot/isolinux/isolinux.bin"
XORRISO_OPTS+=" -c boot/isolinux/boot.cat"
XORRISO_OPTS+=" -boot-load-size 4 -boot-info-table -no-emul-boot"

# UEFI boot options
XORRISO_OPTS+=" -eltorito-alt-boot"
XORRISO_OPTS+=" -e boot/grub/efi.img"
XORRISO_OPTS+=" -no-emul-boot"
XORRISO_OPTS+=" -isohybrid-gpt-basdat"

# Additional options
XORRISO_OPTS+=" -partition_offset 16"
XORRISO_OPTS+=" -append_partition 2 0xEF ${WORK_DIR}/efi.img"

# Output file and source directory
XORRISO_OPTS+=" -o ${OUTPUT_DIR}/${ISO_FILENAME} ${ISO_DIR}"

# Execute xorriso with all options
eval xorriso ${XORRISO_OPTS}

# Post-process the ISO to make it hybrid
if command -v isohybrid >/dev/null 2>&1; then
    echo "Running isohybrid to finalize USB bootability..."
    isohybrid --uefi "${OUTPUT_DIR}/${ISO_FILENAME}" || echo "Warning: isohybrid command failed, but xorriso should have created a hybrid image already."
fi

#xorriso -as mkisofs \
#    -R -J -joliet-long \
#    -V "Whistlekube Installer ${BUILD_VERSION}" \
#    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
#    -c boot/isolinux/boot.cat \
#    -b boot/isolinux/isolinux.bin \
#    -no-emul-boot -boot-load-size 4 -boot-info-table \
#    -eltorito-alt-boot \
#    -append_partition 2 0xef "${ISO_DIR}/EFI/boot/bootx64.efi" \
#    -e EFI/boot/bootx64.efi \
#    -no-emul-boot \
#    -isohybrid-gpt-basdat \
#    -isohybrid-apm-hfsplus \
#    -o "${OUTPUT_DIR}/${ISO_FILENAME}" \
#    "${ISO_DIR}"


#xorriso -as mkisofs \
#    -A "Whistlekube ${BUILD_VERSION}" \
#    -b boot/isolinux/isolinux.bin \
#    -c boot/isolinux/boot.cat \
#    -no-emul-boot -boot-load-size 4 -boot-info-table \
#    -eltorito-alt-boot \
#    -e boot/grub/efi.img \
#    -no-emul-boot \
#    -isohybrid-gpt-basdat \
#    -o "${OUTPUT_DIR}/${ISO_FILENAME}" \
#    "${ISO_DIR}"

# Make the image hybrid
#echo "Making the ISO bootable on USB drives..."
#isohybrid --uefi "${OUTPUT_DIR}/${ISO_FILENAME}" || echo "Warning: isohybrid command failed, USB boot may not work properly."

# Calculate checksum
cd "${OUTPUT_DIR}"
sha256sum "${ISO_FILENAME}" > "${ISO_FILENAME}.sha256"

echo "======================================================"
echo "Build complete!"
echo "ISO file: ${OUTPUT_DIR}/${ISO_FILENAME}"
echo "SHA256: $(cat ${OUTPUT_DIR}/${ISO_FILENAME}.sha256)"
echo "======================================================"

# Clean up
#/scripts/cleanup.sh "${WORK_DIR}"
