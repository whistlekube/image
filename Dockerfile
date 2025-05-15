# syntax=docker/dockerfile:1-labs

# Use a Debian trixie base image
FROM debian:trixie-slim AS debootstrap-builder

# Build arguments
ARG DEBIAN_RELEASE=trixie
ARG DEBIAN_MIRROR=http://deb.debian.org/debian
# This will be automatically set to the build machine's architecture
ARG TARGETARCH

# Set environment variables
ENV WORK_DIR=/build
ENV ISO_DIR="${WORK_DIR}/iso"
ENV CHROOT_INSTALLER_DIR="/whistlekube-chroot-installer"
ENV ROOTFS_DIR="${WORK_DIR}/rootfs"
ENV INITRAMFS_BUILDER_CHROOT_DIR="${WORK_DIR}/initramfs-builder-rootfs"

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV DEBIAN_ARCH="${TARGETARCH}"


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
        syslinux-common \
        syslinux-utils \
        ca-certificates \
        bzip2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /output /build/live-rootfs /build/target-rootfs

WORKDIR ${WORK_DIR}

# Run debootstrap to create the minimal Debian system
# This will be cached by Docker for future builds
RUN echo "=== Debootstraping target rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    debootstrap --arch="${DEBIAN_ARCH}" \
                --variant=minbase \
                "${DEBIAN_RELEASE}" \
                ${ROOTFS_DIR} \
                "${DEBIAN_MIRROR}" && \
    echo "=== Debootstrap DONE ==="


FROM debootstrap-builder AS chroot-base-builder


# Debug: Check what's in the chroot
#RUN echo "=== Contents of /build/chroot ===" && \
#    ls -la /build/chroot && \
#    echo "=== Contents of /build/chroot/bin ===" && \
#    ls -la /build/chroot/bin || echo "No bin directory found" && \
#    echo "=== Contents of /build/chroot/usr/bin ===" && \
#    ls -la /build/chroot/usr/bin || echo "No usr/bin directory found"

# Build initramfs
#RUN echo "Building initramfs..." && \
#    KERNEL_VERSION=$(uname -r) && \
#    mkinitramfs -d ./initrd/etc/initramfs-tools -o ./initrd-live.img ${KERNEL_VERSION}

# Set up policy to prevent services from starting
##RUN echo "#!/bin/sh\nexit 101" > /build/chroot/usr/sbin/policy-rc.d && \
##    chmod +x /build/chroot/usr/sbin/policy-rc.d

# First build a base chroot that all others will be built from
COPY /scripts/run-chroot.sh ./run-chroot.sh
COPY /scripts/chroot-install.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/chroot-install.sh"
COPY /scripts/chroot-cleanup.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/chroot-cleanup.sh"
COPY /chroot-base/packages.list "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/packages.list"
COPY /chroot-base/preinstall.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/preinstall.sh"
RUN --security=insecure \
    echo "=== Configuring base chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    ./run-chroot.sh "${ROOTFS_DIR}" "${CHROOT_INSTALLER_DIR}/chroot-install.sh" && \
    rm -rf "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer"

FROM chroot-base-builder AS chroot-target-builder

# Build the target chroot
COPY /chroot-target/packages.list "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/packages.list"
COPY /scripts/chroot-cleanup.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/postinstall.sh"
RUN --security=insecure \
    echo "=== Configuring target chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    ./run-chroot.sh "${ROOTFS_DIR}" "${CHROOT_INSTALLER_DIR}/chroot-install.sh" && \
    ./run-chroot.sh "${ROOTFS_DIR}" "${CHROOT_INSTALLER_DIR}/chroot-cleanup.sh" && \
    rm -rf "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}" && \
    mksquashfs "${ROOTFS_DIR}" "/target.squashfs" -comp xz -wildcards

FROM chroot-base-builder AS chroot-live-builder

# Setup live chroot environment, run configure-chroot.sh, and clean up
COPY /chroot-live/overlay/ "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/overlay/"
#COPY /chroot-live/install.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/install.sh"
COPY /chroot-live/packages.list "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/packages.list"
COPY /scripts/chroot-cleanup.sh "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}/layer/postinstall.sh"
RUN --security=insecure \
    echo "=== Configuring live chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    ./run-chroot.sh "${ROOTFS_DIR}" "${CHROOT_INSTALLER_DIR}/chroot-install.sh" && \
    ./run-chroot.sh "${ROOTFS_DIR}" "${CHROOT_INSTALLER_DIR}/chroot-cleanup.sh" && \
    rm -rf "${ROOTFS_DIR}${CHROOT_INSTALLER_DIR}" && \
    mksquashfs "${ROOTFS_DIR}" "/live.squashfs" -comp xz -wildcards && \
    echo "=== Chroot configured ==="

FROM initramfs-builder AS initramfs-builder
# Build the initramfs builder chroot
COPY /chroot-initramfs/install.sh "${INITRAMFS_BUILDER_CHROOT_DIR}${CHROOT_INSTALLER_DIR}/install.sh"
RUN --security=insecure \
    echo "=== Configuring initramfs builder chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    ./run-chroot.sh "${INITRAMFS_BUILDER_CHROOT_DIR}" "${CHROOT_INSTALLER_DIR}/install.sh" && \
    rm "${INITRAMFS_BUILDER_CHROOT_DIR}${CHROOT_INSTALLER_DIR}/install.sh" && \
    ./run-chroot.sh "${INITRAMFS_BUILDER_CHROOT_DIR}" "${CHROOT_INSTALLER_DIR}/cleanup.sh"

# Stage 2: Final build environment
# FROM builder as stage-debootstrap-done

# Install required packages for ISO building
# Set environment variables
# ENV DEBIAN_FRONTEND=noninteractive \
#     DEBCONF_NONINTERACTIVE_SEEN=true \
#     PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

FROM chroot-live-builder AS builder

# Build the ISO
COPY /scripts/build-iso.sh ./build-iso.sh
RUN ./build-iso.sh

FROM scratch AS artifact

# Labels following OCI image spec
LABEL org.opencontainers.image.title="Whistlekube Installer ISO Builder"
LABEL org.opencontainers.image.description="A Docker image to build whistlekube installer ISOs"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.authors="Joe Kramer <joe@whistlekube.com>"
LABEL org.opencontainers.image.source="https://github.com/whistlekube/image"

COPY --from=builder /build/iso/whistlekube-installer.iso /whistlekube-installer.iso
