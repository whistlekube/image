set -euox pipefail

# Postinstall script for the live system, runs in the chroot

mkdir -p ${OUTPUT_DIR}/boot

# Copy the kernel and initrd to the output directory
cp /boot/vmlinuz-* ${OUTPUT_DIR}/boot/vmlinuz
cp /boot/initrd.img-* ${OUTPUT_DIR}/boot/initrd.img

systemctl enable whistlekube-installer.service
