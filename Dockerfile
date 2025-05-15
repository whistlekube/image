# syntax=docker/dockerfile:1-labs

# Use a Debian trixie base image
FROM debian:trixie-slim AS builder

# Build arguments
ARG DEBIAN_RELEASE=trixie
ARG DEBIAN_MIRROR=http://deb.debian.org/debian
# This will be automatically set to the build machine's architecture
ARG TARGETARCH

# Labels following OCI image spec
LABEL org.opencontainers.image.title="Whistlekube Installer ISO Builder"
LABEL org.opencontainers.image.description="A Docker image to build whistlekube installer ISOs"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.authors="Joe Kramer <joe@whistlekube.com>"
LABEL org.opencontainers.image.source="https://github.com/whistlekube/image"

# Set environment variables
ENV WORK_DIR=/build
ENV ISO_DIR="${WORK_DIR}/iso"
ENV LIVE_CHROOT_DIR="${WORK_DIR}/live-rootfs"
ENV TARGET_CHROOT_DIR="${WORK_DIR}/target-rootfs"

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV DEBIAN_ARCH="${TARGETARCH}"

# Install required packages for the build process
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        debootstrap \
        xorriso \
        isolinux \
        syslinux-common \
        syslinux-utils \
        cpio \
        genisoimage \
        dosfstools \
        squashfs-tools \
        mtools \
        binutils \
        ca-certificates \
        curl \
        gnupg \
        rsync \
        sudo \
        xz-utils \
        file \
        bzip2 \
        lsof \
        live-boot \
        live-boot-initramfs-tools \
        initramfs-tools \
        procps \
        psmisc \
        strace \
        vim-tiny \
        less \
        iproute2 \
        grub-common \
        grub-efi-amd64-bin \
        grub-pc-bin \
        grub2-common \
        kpartx \
        parted \
        zstd \
        gdisk && \
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
                ${TARGET_CHROOT_DIR} \
                "${DEBIAN_MIRROR}" && \
    echo "=== Debootstrap DONE ==="

# Debug: Check what's in the chroot
#RUN echo "=== Contents of /build/chroot ===" && \
#    ls -la /build/chroot && \
#    echo "=== Contents of /build/chroot/bin ===" && \
#    ls -la /build/chroot/bin || echo "No bin directory found" && \
#    echo "=== Contents of /build/chroot/usr/bin ===" && \
#    ls -la /build/chroot/usr/bin || echo "No usr/bin directory found"

# Set up policy to prevent services from starting
##RUN echo "#!/bin/sh\nexit 101" > /build/chroot/usr/sbin/policy-rc.d && \
##    chmod +x /build/chroot/usr/sbin/policy-rc.d

# Setup target chroot environment, run configure-chroot.sh, and clean up
COPY /scripts/run-chroot.sh ./run-chroot.sh
COPY /chroot-target/packages.list "${TARGET_CHROOT_DIR}/packages.list"
COPY /chroot-target/base-install.sh "${TARGET_CHROOT_DIR}/base-install.sh"
COPY /scripts/chroot-cleanup.sh "${TARGET_CHROOT_DIR}/cleanup.sh"
RUN --security=insecure \
    echo "=== Configuring base chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    cp /etc/resolv.conf "${TARGET_CHROOT_DIR}/etc/resolv.conf" && \
    ./run-chroot.sh "${TARGET_CHROOT_DIR}" "/base-install.sh" && \
    rm "${TARGET_CHROOT_DIR}/base-install.sh" && \
    rm "${TARGET_CHROOT_DIR}/packages.list" && \
    cp -r "${TARGET_CHROOT_DIR}" "${LIVE_CHROOT_DIR}"

COPY /chroot-target/install.sh "${TARGET_CHROOT_DIR}/install.sh"
RUN --security=insecure \
    echo "=== Configuring target chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    cp /etc/resolv.conf "${TARGET_CHROOT_DIR}/etc/resolv.conf" && \
    ./run-chroot.sh "${TARGET_CHROOT_DIR}" "/install.sh" && \
    rm "${TARGET_CHROOT_DIR}/install.sh" && \
    ./run-chroot.sh "${TARGET_CHROOT_DIR}" "/cleanup.sh"

# Setup live chroot environment, run configure-chroot.sh, and clean up
COPY /chroot-live/install.sh "${LIVE_CHROOT_DIR}/install.sh"
RUN --security=insecure \
    echo "=== Configuring live chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    cp /etc/resolv.conf "${LIVE_CHROOT_DIR}/etc/resolv.conf" && \
    ./run-chroot.sh "${LIVE_CHROOT_DIR}" "/install.sh" && \
    rm "${LIVE_CHROOT_DIR}/install.sh" && \
    ./run-chroot.sh "${LIVE_CHROOT_DIR}" "/cleanup.sh" && \
    echo "=== Chroot configured ==="

# Stage 2: Final build environment
# FROM builder as stage-debootstrap-done

# Install required packages for ISO building
# Set environment variables
# ENV DEBIAN_FRONTEND=noninteractive \
#     DEBCONF_NONINTERACTIVE_SEEN=true \
#     PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Copy scripts and make them executable
#COPY config/ /config/

# Build the ISO
COPY /scripts/build-iso.sh ./build-iso.sh
RUN ./build-iso.sh

# Set entrypoint to the build script
#ENTRYPOINT ["/scripts/build-iso.sh"]

# Default command (can be overridden)
#CMD ["BUILD_VERSION=latest", "ISO_FILENAME=whistlekube-installer.iso"]

FROM scratch AS artifact
COPY --from=builder /build/iso/whistlekube-installer.iso /whistlekube-installer.iso
