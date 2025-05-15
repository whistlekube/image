# syntax=docker/dockerfile:1-labs

# Global build arguments
ARG DEBIAN_RELEASE=trixie
ARG DEBIAN_MIRROR=http://deb.debian.org/debian

ARG ISO_LABEL="WHISTLEKUBE_ISO"
ARG ISO_APPID="Whistlekube Installer"
ARG ISO_PUBLISHER="Whistlekube"
ARG ISO_PREPARER="Built with xorriso"
ARG ISO_OUTPUT_FILE="/whistlekube-installer.iso"

FROM debian:${DEBIAN_RELEASE}-slim AS builder-base

# Pass global build arguments to this stage
ARG DEBIAN_RELEASE
ARG DEBIAN_MIRROR

# This will be automatically set to the build machine's architecture
ARG TARGETARCH

# Set environment variables
ENV ROOTFS_DIR="/rootfs"
ENV CHROOT_OUTPUT_DIR="/output"
ENV ISO_DIR="/iso"
ENV DEBIAN_RELEASE=${DEBIAN_RELEASE}
ENV DEBIAN_MIRROR=${DEBIAN_MIRROR}
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV DEBIAN_ARCH="${TARGETARCH}"

# Use a Debian trixie base image
FROM builder-base AS debootstrap-builder


#xorriso \
#isolinux \
#cpio \
#genisoimage \
#dosfstools \
#squashfs-tools \
#mtools \
#binutils \
#gnupg \
#rsync \
#sudo \
#xz-utils \
#file \
#lsof \
#procps \
#psmisc \
#strace \
#vim-tiny \
#less \
#iproute2 \
#grub-common \
#grub-efi-amd64-bin \
#grub-pc-bin \
#grub2-common \
#kpartx \
#parted \
#zstd \
#gdisk \


# Install required packages for the build process
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        debootstrap \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#--include=base-files,base-passwd,dash,debconf,debian-archive-keyring,debianutils,apt,apt-utils,dpkg,systemd-sysv,locales,tzdata,util-linux \

# Run debootstrap to create the minimal Debian system
# This will be cached by Docker for future builds
RUN echo "=== Debootstraping base rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    mkdir -p ${ROOTFS_DIR} && \
    debootstrap --arch="${DEBIAN_ARCH}" \
                --variant=minbase \
                --include=zstd \
                "${DEBIAN_RELEASE}" \
                ${ROOTFS_DIR} \
                "${DEBIAN_MIRROR}" && \
    echo "=== Debootstrap DONE ==="


#FROM debootstrap-builder AS chroot-base-builder
#
#RUN apt-get update && \
#    apt-get install -y --no-install-recommends \
#        squashfs-tools && \
#    apt-get clean && \
#    rm -rf /var/lib/apt/lists/*
#
## Debug: Check what's in the chroot
##RUN echo "=== Contents of /build/chroot ===" && \
##    ls -la /build/chroot && \
##    echo "=== Contents of /build/chroot/bin ===" && \
##    ls -la /build/chroot/bin || echo "No bin directory found" && \
##    echo "=== Contents of /build/chroot/usr/bin ===" && \
##    ls -la /build/chroot/usr/bin || echo "No usr/bin directory found"
#
## Build initramfs
##RUN echo "Building initramfs..." && \
##    KERNEL_VERSION=$(uname -r) && \
##    mkinitramfs -d ./initrd/etc/initramfs-tools -o ./initrd-live.img ${KERNEL_VERSION}
#
## Set up policy to prevent services from starting
###RUN echo "#!/bin/sh\nexit 101" > /build/chroot/usr/sbin/policy-rc.d && \
###    chmod +x /build/chroot/usr/sbin/policy-rc.d
#
## First build a base chroot that all others will be built from
#COPY /scripts/run-chroot.sh /scripts/run-chroot.sh
#COPY /scripts/chroot-install.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/chroot-install.sh"
#COPY /scripts/chroot-cleanup.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/chroot-cleanup.sh"
#COPY /chroot-base/packages.list "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/packages.list"
#COPY /chroot-base/preinstall.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/preinstall.sh"
#RUN --security=insecure \
#    echo "=== Configuring base chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
#    /scripts/run-chroot.sh "${ROOTFS_DIR}" "${CHROOT_INSTALLER_DIR}/chroot-install.sh" && \
#    rm -rf "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer"
#
#FROM chroot-base-builder AS chroot-target-builder
#
## Build the target chroot
#COPY /chroot-target/packages.list "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/packages.list"
#COPY /scripts/chroot-cleanup.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/postinstall.sh"
#RUN --security=insecure \
#    echo "=== Configuring target chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
#    /scripts/run-chroot.sh "${ROOTFS_DIR}" "${CHROOT_INSTALLER_DIR}/chroot-install.sh" && \
#    /scripts/run-chroot.sh "${ROOTFS_DIR}" "${CHROOT_INSTALLER_DIR}/chroot-cleanup.sh" && \
#    rm -rf "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}" && \
#    mksquashfs "${ROOTFS_DIR}" "/target.squashfs" -comp xz -wildcards

FROM debootstrap-builder AS chroot-builder

# Install required packages for the build process
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        squashfs-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

FROM chroot-builder AS chroot-live-builder

# Setup live chroot environment, run configure-chroot.sh, and clean up
COPY /chroot-live/overlay/ "${ROOTFS_DIR}/"
#COPY /chroot-live/install.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/install.sh"
#COPY /chroot-live/packages.list "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/packages.list"
#COPY /chroot-live/postinstall.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/postinstall.sh"
COPY /scripts/chroot-live.sh "${ROOTFS_DIR}/chroot-live.sh"
RUN --security=insecure \
    echo "=== Configuring live chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    chroot "${ROOTFS_DIR}" /chroot-live.sh && \
    echo "=== Copying kernel and initrd ===" && \
    ls -la "${ROOTFS_DIR}/boot" && \
    cp ${ROOTFS_DIR}/boot/vmlinuz-* "/vmlinuz" && \
    cp ${ROOTFS_DIR}/boot/initrd.img-* "/initrd.img" && \
    echo "=== Cleaning up chroot ===" && \
    rm -rf ${ROOTFS_DIR}/{boot,initrd.img*,vmlinuz*} && \
    echo "=== Squashing filesystem ===" && \
    mksquashfs "${ROOTFS_DIR}" "/filesystem.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M -e boot && \
    echo "=== Chroot configured ==="

# Build the initramfs
#FROM chroot-live-builder AS initramfs-builder
#ENV OUTPUT_DIR="/output"
#ENV ISO_DIR="/iso"
#COPY /scripts/chroot-install.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/chroot-install.sh"
#COPY /scripts/chroot-cleanup.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/chroot-cleanup.sh"
#COPY /chroot-initramfs/postinstall.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/postinstall.sh"
#COPY /chroot-initramfs/packages.list "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/packages.list"
##COPY /scripts/chroot-cleanup.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/postinstall.sh"
#RUN --security=insecure \
#    echo "=== Configuring initramfs builder chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
#    mkdir -p ${ISO_DIR}/EFI/boot && \
#    mkdir -p ${ISO_DIR}/boot/grub && \
#    mkdir -p "${OUTPUT_DIR}" && \
#    /scripts/run-chroot.sh "${ROOTFS_DIR}" "${CHROOT_INSTALLER_DIR}/chroot-install.sh" && \
#    ls -la "${ROOTFS_DIR}/usr/lib/ISOLINUX" && \
#    cp -a "${ROOTFS_DIR}${OUTPUT_DIR}/" "${ISO_DIR}/" && \
#    echo "=== Chroot configured ==="

# Stage 2: Final build environment
# FROM builder as stage-debootstrap-done

# Install required packages for ISO building
# Set environment variables
# ENV DEBIAN_FRONTEND=noninteractive \
#     DEBCONF_NONINTERACTIVE_SEEN=true \
#     PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

FROM builder-base AS iso-builder

ARG ISO_LABEL
ARG ISO_APPID
ARG ISO_PUBLISHER
ARG ISO_PREPARER
ARG ISO_OUTPUT_FILE

ENV EFI_MOUNT_POINT="/efimount"
ENV ISO_EFI_DIR="${ISO_DIR}/EFI"

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
#COPY --from=chroot-target-builder /target.squashfs ${ISO_DIR}/live/target.squashfs
COPY --from=chroot-live-builder "/filesystem.squashfs" "${ISO_DIR}/live/filesystem.squashfs"
COPY --from=chroot-live-builder "/vmlinuz" "${ISO_DIR}/live/vmlinuz"
COPY --from=chroot-live-builder "/initrd.img" "${ISO_DIR}/live/initrd.img"
COPY /iso-files/boot/grub/grub.cfg ${ISO_DIR}/boot/grub/grub.cfg
#COPY --from=initramfs-builder /iso/output/ ${ISO_DIR}/

##    grub-mkstandalone \
##        --compress=xz \
##        --modules="part_gpt part_msdos" \
##        --format=x86_64-efi \
##        --output="${ISO_DIR}/EFI/boot/bootx64.efi" \
##        --locales="" \
##        --fonts="" \
##        --themes="" \
##        "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg" && \
##    mkfs.vfat "${ISO_DIR}/EFI/boot/efi.img" && \
##    mmd -i "${ISO_DIR}/EFI/boot/efi.img" ::/EFI ::/EFI/boot && \
##    mcopy -i "${ISO_DIR}/EFI/boot/efi.img" "${ISO_DIR}/EFI/boot/bootx64.efi" ::/EFI/boot/ && \
##    grub-mkstandalone \
##        --format=i386-pc \
##        --output="${ISO_DIR}/boot/grub/core.img" \
##        --install-modules="linux normal iso9660 biosdisk memdisk search" \
##        --modules="linux normal iso9660 biosdisk search" \
##        --locales="" \
##        --fonts="" \
##        "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg" && \
##    cat /usr/lib/grub/i386-pc/cdboot.img "${ISO_DIR}/boot/grub/core.img" > "${ISO_DIR}/boot/grub/bios.img" && \
##    ls -la "${ISO_DIR}/boot/isolinux" && \
##    xorriso -as mkisofs \
##        -R -J -joliet-long \
##        -V "WHISTLEKUBE_ISO" \
##        -publisher "Whistlekube" \
##        -isohybrid-mbr "${ISO_DIR}/boot/isolinux/isohdpfx.bin" \
##        -b boot/isolinux/isolinux.bin \
##        -c boot/isolinux/boot.cat \
##        -no-emul-boot -boot-load-size 4 -boot-info-table \
##        -eltorito-alt-boot \
##        -append_partition 2 0xef "${ISO_DIR}/EFI/boot/efi.img" \
##        -e EFI/boot/efi.img \
##        -no-emul-boot \
##        -isohybrid-gpt-basdat \
##        -partition_offset 16 \
##        -o "${ISO_DIR}/whistlekube-installer.iso" "${ISO_DIR}"


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

# Build the ISO
#COPY /scripts/build-iso.sh ./build-iso.sh
#RUN ./build-iso.sh

FROM scratch AS artifact

ARG ISO_OUTPUT_FILE

# Labels following OCI image spec
LABEL org.opencontainers.image.title="Whistlekube Installer ISO Builder"
LABEL org.opencontainers.image.description="A Docker image to build whistlekube installer ISOs"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.authors="Joe Kramer <joe@whistlekube.com>"
LABEL org.opencontainers.image.source="https://github.com/whistlekube/image"

COPY --from=iso-builder ${ISO_OUTPUT_FILE} /
