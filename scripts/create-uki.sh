#!/bin/bash
set -e

# Configuration variables
MACHINE_ID=$(uuidgen)
ROOTFS_DIR=${ROOTFS_DIR:-/rootfs}
KERNEL_VERSION=$(ls ${ROOTFS_DIR}/lib/modules/ | head -n1)
OUTPUT_DIR=${OUTPUT_DIR:-/output}

echo "Creating Unified Kernel Image (UKI)..."
mkdir -p ${OUTPUT_DIR}

# Create a stub EFI config (cmdline)
cat > /tmp/cmdline.txt << EOF
root=LABEL=WhistleKube ro quiet splash loglevel=3 rd.udev.log_priority=3 systemd.unified_cgroup_hierarchy=1 systemd.machine_id=$MACHINE_ID net.ifnames=0 network.managed=0 ipv6.disable=1
EOF

# Create a stub systemd-boot config
mkdir -p /tmp/efi/loader/entries
cat > /tmp/efi/loader/loader.conf << EOF
default whistlekube.conf
timeout 3
console-mode auto
editor no
EOF

cat > /tmp/efi/loader/entries/whistlekube.conf << EOF
title WhistleKube
linux /EFI/Linux/vmlinuz-$KERNEL_VERSION
initrd /EFI/Linux/initrd.img-$KERNEL_VERSION
options root=LABEL=WhistleKube ro quiet splash loglevel=3 rd.udev.log_priority=3 systemd.unified_cgroup_hierarchy=1 systemd.machine_id=$MACHINE_ID net.ifnames=0 network.managed=0 ipv6.disable=1
EOF

# Extract kernel and initramfs
mkdir -p /tmp/uki-build
cp ${ROOTFS_DIR}/boot/vmlinuz-$KERNEL_VERSION /tmp/uki-build/linux
cp ${ROOTFS_DIR}/boot/initrd.img-$KERNEL_VERSION /tmp/uki-build/initrd

# Create stub initramfs if we need to add more components
mkdir -p /tmp/dracut-overlay
# Add squashfs to initramfs overlay
mkdir -p /tmp/dracut-overlay/lib/modules/$KERNEL_VERSION/kernel/fs
cp -a ${ROOTFS_DIR}/lib/modules/$KERNEL_VERSION/kernel/fs/squashfs /tmp/dracut-overlay/lib/modules/$KERNEL_VERSION/kernel/fs/

# Add custom dracut modules for handling the immutable root and overlays
mkdir -p /tmp/dracut-overlay/usr/lib/dracut/modules.d/90immutaroot
cat > /tmp/dracut-overlay/usr/lib/dracut/modules.d/90immutaroot/module-setup.sh << EOF
#!/bin/bash
check() {
    return 0
}

depends() {
    echo systemd
    return 0
}

install() {
    inst_hook pre-mount 90 "\$moddir/mount-immuta.sh"
    inst_multiple grep mount mkdir
}
EOF

cat > /tmp/dracut-overlay/usr/lib/dracut/modules.d/90immutaroot/mount-immuta.sh << EOF
#!/bin/sh
# Mount the immutable root filesystem

# Wait for the device with our squashfs
echo "Waiting for ImmutaDebian root device..."
udevadm settle

# Assuming the squashfs is on a partition labeled ImmutaDebian
ROOT_DEV=\$(blkid -L ImmutaDebian)

if [ -z "\$ROOT_DEV" ]; then
    echo "Could not find ImmutaDebian root device!"
    exit 1
fi

# Create mount points
mkdir -p /sysroot
mkdir -p /run/overlayfs

# Mount the squashfs
mount -t squashfs \$ROOT_DEV /sysroot

# Setup RAM overlay
mkdir -p /run/overlayfs/upper
mkdir -p /run/overlayfs/work

# Mount the overlayfs
mount -t overlay -o lowerdir=/sysroot,upperdir=/run/overlayfs/upper,workdir=/run/overlayfs/work overlay /sysroot

# We're done
exit 0
EOF

chmod +x /tmp/dracut-overlay/usr/lib/dracut/modules.d/90immutaroot/module-setup.sh
chmod +x /tmp/dracut-overlay/usr/lib/dracut/modules.d/90immutaroot/mount-immuta.sh

# Create an updated initramfs with our overlays
chroot ${ROOTFS_DIR} dracut --force --add "systemd squashfs overlay immutaroot" \
  --modules "systemd kernel-modules base udev-rules dracut-systemd usrmount fs-lib shutdown" \
  --omit "network network-legacy ifcfg biosdevname" \
  --no-hostonly --no-compress /boot/initrd-immuta.img $KERNEL_VERSION

cp ${ROOTFS_DIR}/boot/initrd-immuta.img /tmp/uki-build/initrd

# UKI - Use systemd-boot to create the combined UKI
mkdir -p ${ROOTFS_DIR}/boot/efi/EFI/BOOT
mkdir -p ${ROOTFS_DIR}/boot/efi/EFI/Linux

# Build UKI using ukify if available, or manually assemble it
if command -v ukify >/dev/null 2>&1; then
    # Using ukify (part of newer systemd)
    ukify build \
        --linux=/tmp/uki-build/linux \
        --initrd=/tmp/uki-build/initrd \
        --cmdline="$(cat /tmp/cmdline.txt)" \
        --output="$OUTPUT_DIR/linux.efi"
else
    # Manual assembly - this is a simplified version
    objcopy \
        --add-section .linux=/tmp/uki-build/linux \
        --change-section-vma .linux=0x2000000 \
        --add-section .initrd=/tmp/uki-build/initrd \
        --change-section-vma .initrd=0x3000000 \
        ${ROOTFS_DIR}/usr/lib/systemd/boot/efi/linuxx64.efi.stub \
        "$OUTPUT_DIR/linux.efi"
fi

# Copy the UKI to the right locations
cp "$OUTPUT_DIR/linux.efi" ${ROOTFS_DIR}/boot/efi/EFI/BOOT/BOOTX64.EFI
cp "$OUTPUT_DIR/linux.efi" ${ROOTFS_DIR}/boot/efi/EFI/Linux/

echo "UKI creation complete!"
