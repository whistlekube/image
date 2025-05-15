set -euox pipefail

# This script runs inside the chroot to configure the initramfs builder system

OUTPUT_DIR=${OUTPUT_DIR:-"/output"}

KERNEL_VERSION=$(ls -1 /lib/modules/ | sort -V | tail -n 1)

mkdir -p ${OUTPUT_DIR}/boot/isolinux

# Build initramfs
echo "Building initramfs for kernel version ${KERNEL_VERSION}..."
mkinitramfs -d etc/initramfs-tools -o ${OUTPUT_DIR}/boot/initrd.img ${KERNEL_VERSION}

# Copy kernel to output directory
cp /boot/vmlinuz-${KERNEL_VERSION} ${OUTPUT_DIR}/boot/vmlinuz

# Copy isolinux files
ls -la /usr/lib/
cp /usr/lib/ISOLINUX/isolinux.bin ${OUTPUT_DIR}/boot/isolinux/ && \
cp /usr/lib/ISOLINUX/isohdpfx.bin ${OUTPUT_DIR}/boot/isolinux/ && \
cp /usr/lib/syslinux/modules/bios/{ldlinux.c32,libcom32.c32,libutil.c32,menu.c32,vesamenu.c32} ${OUTPUT_DIR}/boot/isolinux/
