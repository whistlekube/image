# syntax=docker/dockerfile:1-labs

# Global build arguments
ARG DEBIAN_RELEASE=trixie
ARG DEBIAN_MIRROR=http://deb.debian.org/debian

ARG ISO_OUTPUT_FILE="/whistlekube-installer.iso"

FROM debian:${DEBIAN_RELEASE}-slim AS base

# Pass global build arguments to this stage
ARG DEBIAN_RELEASE
ARG DEBIAN_MIRROR

# This will be automatically set to the build machine's architecture
ARG TARGETARCH

# Set environment variables
ENV ROOTFS_DIR="/rootfs"
ENV CHROOT_OUTPUT_DIR="/output"
ENV DEBIAN_RELEASE=${DEBIAN_RELEASE}
ENV DEBIAN_MIRROR=${DEBIAN_MIRROR}
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV DEBIAN_ARCH="${TARGETARCH}"

# Use a Debian trixie base image
FROM base AS debootstrap-builder

# Install required packages for the build process
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        debootstrap \
        squashfs-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Run debootstrap to create the minimal Debian system
# This forms the base for both the target and live chroot environments
RUN echo "=== Debootstraping base rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    mkdir -p ${ROOTFS_DIR} && \
    debootstrap --arch="${DEBIAN_ARCH}" \
                --variant=minbase \
                --include=zstd \
                "${DEBIAN_RELEASE}" \
                ${ROOTFS_DIR} \
                "${DEBIAN_MIRROR}" && \
    echo "=== Debootstrap DONE ==="

COPY /overlays/chroot-base/ "${ROOTFS_DIR}/"

# Setup live chroot environment, run configure-chroot.sh, and clean up
FROM debootstrap-builder AS chroot-live-builder

COPY /overlays/live/ "${ROOTFS_DIR}/"
#COPY /chroot-live/install.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/install.sh"
#COPY /chroot-live/packages.list "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/packages.list"
#COPY /chroot-live/postinstall.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/postinstall.sh"
#COPY /scripts/chroot-live.sh "${ROOTFS_DIR}/chroot-live.sh"
RUN --security=insecure \
    echo "=== Configuring live chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    chroot "${ROOTFS_DIR}" /chroot-install.sh && \
    echo "=== Copying kernel and initrd from live chroot ===" && \
    ls -la "${ROOTFS_DIR}/boot" && \
    cp ${ROOTFS_DIR}/boot/vmlinuz-* "/vmlinuz" && \
    cp ${ROOTFS_DIR}/boot/initrd.img-* "/initrd.img" && \
    echo "=== Cleaning up live chroot ===" && \
    rm -rf ${ROOTFS_DIR}/{boot,chroot-install.sh,initrd.img*,vmlinuz*} && \
    echo "=== Squashing live filesystem ===" && \
    mksquashfs "${ROOTFS_DIR}" "/filesystem.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M -e boot && \
    echo "=== Chroot configured for live ==="

FROM debootstrap-builder AS chroot-target-builder

COPY /overlays/target/ "${ROOTFS_DIR}/"

RUN --security=insecure \
    echo "=== Configuring target chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    chroot "${ROOTFS_DIR}" /chroot-install.sh && \
    echo "=== Cleaning up target chroot ===" && \
    rm -rf ${ROOTFS_DIR}/{boot,chroot-install.sh,initrd.img*,vmlinuz*} && \
    echo "=== Squashing target filesystem ===" && \
    mksquashfs "${ROOTFS_DIR}" "/filesystem.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M -e boot && \
    echo "=== Chroot configured for target ==="

FROM base AS iso-builder

ARG ISO_OUTPUT_FILE

ARG ISO_LABEL="WHISTLEKUBE_ISO"
ARG ISO_APPID="Whistlekube Installer"
ARG ISO_PUBLISHER="Whistlekube"
ARG ISO_PREPARER="Built with xorriso"

ENV ISO_DIR="/iso"
ENV ISO_EFI_DIR="${ISO_DIR}/EFI"
ENV EFI_MOUNT_POINT="/efimount"

WORKDIR /build

# Install required packages for the build process
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        grub-pc-bin \
        grub-efi-amd64-bin \
        grub2-common \
        xz-utils \
        xorriso \
        cpio \
        genisoimage \
        dosfstools \
        mtools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy the live and target filesystems from the chroot builders
COPY --from=chroot-live-builder /filesystem.squashfs "${ISO_DIR}/live/filesystem.squashfs"
COPY --from=chroot-live-builder /vmlinuz "${ISO_DIR}/live/vmlinuz"
COPY --from=chroot-live-builder /initrd.img "${ISO_DIR}/live/initrd.img"
COPY --from=chroot-target-builder /filesystem.squashfs "${ISO_DIR}/installer/target.squashfs"
# Copy the GRUB configuration file
COPY /overlays/iso/ ${ISO_DIR}/

# Build the GRUB images for BIOS and EFI boot and the final ISO
RUN --security=insecure \
    echo "=== Building GRUB for BIOS boot ===" && \
    grub-mkimage \
        -O i386-pc-eltorito \
        -o "${ISO_DIR}/boot/grub/core.img" \
        -p /boot/grub \
        biosdisk iso9660 \
        normal configfile \
        echo linux search search_label \
        part_msdos part_gpt fat ext2 && \
    echo "=== Building GRUB for EFI boot ===" && \
    mkdir -p ${ISO_DIR}/EFI && \
    dd if=/dev/zero of="${ISO_DIR}/EFI/efiboot.img" bs=1M count=10 && \
    mkfs.vfat -F 32 "${ISO_DIR}/EFI/efiboot.img" && \
    mkdir -p "${EFI_MOUNT_POINT}" && \
    mount -o loop "${ISO_DIR}/EFI/efiboot.img" "${EFI_MOUNT_POINT}" && \
    mkdir -p "${EFI_MOUNT_POINT}/EFI/BOOT" && \
    grub-mkimage \
        -O x86_64-efi \
        -o "${EFI_MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI" \
        -p /boot/grub \
        iso9660 normal configfile \
        echo linux search search_label \
        part_msdos part_gpt fat ext2 efi_gop efi_uga \
        all_video font && \
    cp "${ISO_DIR}/boot/grub/grub.cfg" "${EFI_MOUNT_POINT}/EFI/BOOT/grub.cfg" && \
    umount "${EFI_MOUNT_POINT}" && \
    rmdir "${EFI_MOUNT_POINT}" && \
    find ${ISO_DIR} && \
    xorriso \
        -as mkisofs \
        -iso-level 3 \
        \
        # Filesystem extensions for compatibility and long filenames
        -rock --joliet --joliet-long \
        -full-iso9660-filenames \
        \
        # ISO Volume Information
        -volid "${ISO_LABEL}" \
        -appid "${ISO_APPID}" \
        -publisher "${ISO_PUBLISHER}" \
        -preparer "${ISO_PREPARER}" \
        \
        # El Torito primary boot entry (for BIOS CD/DVD and BIOS USB via hybrid MBR)
        # Points to the GRUB2 BIOS core image on the ISO
        -eltorito-boot boot/grub/core.img \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            --grub2-boot-info \
        \
        # El Torito alternative boot entry (for UEFI CD/DVD)
        # Points to the EFI system image on the ISO
        -eltorito-alt-boot \
            -e EFI/efiboot.img \
            -no-emul-boot \
        \
        # Hybrid MBR configuration
        -isohybrid-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
        -append_partition 2 0xef "${ISO_DIR}/EFI/efiboot.img" \
        -isohybrid-gpt-basdat \
        -output "/${ISO_OUTPUT_FILE}" \
        "${ISO_DIR}" && \
    echo "=== ISO build complete ==="

FROM scratch AS artifact

ARG ISO_OUTPUT_FILE

# Labels following OCI image spec
LABEL org.opencontainers.image.title="Whistlekube Installer ISO Builder"
LABEL org.opencontainers.image.description="A Docker image to build whistlekube installer ISOs"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.authors="Joe Kramer <joe@whistlekube.com>"
LABEL org.opencontainers.image.source="https://github.com/whistlekube/image"

COPY --from=iso-builder ${ISO_OUTPUT_FILE} /
