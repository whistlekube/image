# syntax=docker/dockerfile:1-labs

# Global build arguments
ARG DEBIAN_RELEASE="trixie"
ARG BUILD_VERSION="unknown"
ARG DEBIAN_MIRROR="http://deb.debian.org/debian"
ARG ISO_FILENAME="whistlekube-${DEBIAN_RELEASE}-${BUILD_VERSION}.iso"
ARG OUTPUT_DIR="/output"

# === Base builder ===
FROM debian:${DEBIAN_RELEASE}-slim AS base-builder

# Pass global build arguments to this stage
ARG DEBIAN_RELEASE
ARG DEBIAN_MIRROR
ARG OUTPUT_DIR

# This will be automatically set to the build machine's architecture
ARG TARGETARCH

# Set common environment variables
ENV ROOTFS_DIR="/rootfs"
ENV CHROOT_BOOTSTRAP_DIR="/whistlekube-bootstrap"
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV DEBIAN_ARCH="${TARGETARCH}"

# === Base chroot build ===
# This stage builds the base chroot environment that is used for both the target and live root filesystems
FROM base-builder AS chroot-builder

# Install required packages for the build process
# Then run debootstrap to create the minimal Debian system
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        debootstrap \
        ca-certificates \
        squashfs-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo "=== Debootstraping base rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    mkdir -p ${ROOTFS_DIR} && \
    debootstrap --arch="${DEBIAN_ARCH}" \
                --variant=minbase \
                "${DEBIAN_RELEASE}" \
                ${ROOTFS_DIR} \
                "${DEBIAN_MIRROR}" && \
    echo "=== Debootstrap DONE ==="

# Copy the base overlay and run base bootstrap script
COPY /overlays/base/ "${ROOTFS_DIR}/"
RUN --security=insecure \
    echo "=== Configuring base chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    chroot "${ROOTFS_DIR}" "${CHROOT_BOOTSTRAP_DIR}/bootstrap-base.sh" && \
    echo "=== Chroot configured for base ==="

# === Live chroot build ===
# This stage builds the live chroot environment that is used for the live installer
# Outputs kernel, initrd, and filesystem.squashfs binaries
FROM chroot-builder AS livefs-build

# Copy the live overlay and run live bootstrap script
COPY /overlays/live/ "${ROOTFS_DIR}/"
RUN --security=insecure \
    echo "=== Configuring live chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    chroot "${ROOTFS_DIR}" "${CHROOT_BOOTSTRAP_DIR}/bootstrap-live.sh" && \
    echo "=== Copying kernel and initrd from live chroot ===" && \
    mkdir -p "${OUTPUT_DIR}" && \
    cp ${ROOTFS_DIR}/boot/vmlinuz-* "${OUTPUT_DIR}/vmlinuz" && \
    cp ${ROOTFS_DIR}/boot/initrd.img-* "${OUTPUT_DIR}/initrd.img" && \
    echo "=== Cleaning up live chroot ===" && \
    chroot "${ROOTFS_DIR}" "${CHROOT_BOOTSTRAP_DIR}/cleanup-live.sh" && \
    rm -rf "${ROOTFS_DIR}${CHROOT_BOOTSTRAP_DIR}" && \
    echo "=== Squashing live filesystem ===" && \
    mksquashfs "${ROOTFS_DIR}" "${OUTPUT_DIR}/filesystem.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M -e boot && \
    echo "=== Chroot configured for live ==="

# === Target chroot build ===
# This stage builds the target chroot environment that is used for the target filesystem
# Outputs filesystem.squashfs binary
FROM chroot-builder AS targetfs-build
COPY /overlays/target/ "${ROOTFS_DIR}/"
RUN --security=insecure \
    echo "=== Configuring target chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    chroot "${ROOTFS_DIR}" "${CHROOT_BOOTSTRAP_DIR}/bootstrap-target.sh" && \
    echo "=== Squashing target filesystem ===" && \
    mkdir -p "${OUTPUT_DIR}" && \
    mksquashfs "${ROOTFS_DIR}" "${OUTPUT_DIR}/filesystem.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M && \
    echo "=== Chroot configured for target ==="

# === ISO build ===
# This stage builds the grub images and the final bootable ISO
FROM base-builder AS iso-build

ARG ISO_LABEL="WHISTLEKUBE_ISO"
ARG ISO_APPID="Whistlekube Installer"
ARG ISO_PUBLISHER="Whistlekube"
ARG ISO_PREPARER="Built with xorriso"
ARG ISO_FILENAME

ENV ISO_DIR="/iso"
ENV ISO_EFI_DIR="${ISO_DIR}/EFI"
ENV EFI_MOUNT_POINT="/efimount"

WORKDIR /build

# Install required packages for the build process
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
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

# Copy the kernel, initrd, and squashfs files from the chroot builders
COPY --from=livefs-build ${OUTPUT_DIR}/filesystem.squashfs ${ISO_DIR}/live/filesystem.squashfs
COPY --from=livefs-build ${OUTPUT_DIR}/vmlinuz ${ISO_DIR}/live/vmlinuz
COPY --from=livefs-build ${OUTPUT_DIR}/initrd.img ${ISO_DIR}/live/initrd.img
COPY --from=targetfs-build ${OUTPUT_DIR}/filesystem.squashfs ${ISO_DIR}/installer/target.squashfs
# Copy the ISO overlay files
COPY /overlays/iso/ ${ISO_DIR}/
# Copy the ISO build script
COPY /scripts/build-iso.sh .

# Build the GRUB images for BIOS and EFI boot and the final ISO
RUN --security=insecure \
    ./build-iso.sh

# === Artifact ===
# This stage builds the final artifact container
# It simply copies the output directory from the ISO builder stage
FROM scratch AS artifact

ARG OUTPUT_DIR

# Labels following OCI image spec
LABEL org.opencontainers.image.title="Whistlekube Installer ISO Artifacts"
LABEL org.opencontainers.image.description="Image containing the whistlekube installer ISO and other artifacts"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="Joe Kramer <joe@whistlekube.com>"
LABEL org.opencontainers.image.source="https://github.com/whistlekube/image"

COPY --from=iso-build ${OUTPUT_DIR}/ /
