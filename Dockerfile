# syntax=docker/dockerfile:1-labs

# Global build arguments
ARG DEBIAN_RELEASE="trixie"
ARG BUILD_VERSION="UNKNOWNVERSION"
ARG DEBIAN_MIRROR="http://deb.debian.org/debian"
ARG ISO_FILENAME="whistlekube-installer-${BUILD_VERSION}.iso"
ARG OUTPUT_DIR="/output"

# === Base builder ===
FROM debian:${DEBIAN_RELEASE}-slim AS base-builder

ARG DEBIAN_RELEASE
ARG DEBIAN_MIRROR
ARG OUTPUT_DIR

# This will be automatically set to the build machine's architecture
ARG TARGETARCH

# Set common environment variables
ENV DEBIAN_ARCH="${TARGETARCH}"
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# === Base rootfs builder with tools installed ===
# This stage builds the base chroot environment that is used for both the target and live root filesystems
FROM base-builder AS rootfs-builder
# Install required packages for the build process
# Then run debootstrap to create the minimal Debian system
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists <<EOFDOCKER
set -eux
apt-get update
apt-get install -y --no-install-recommends \
    mmdebstrap \
    xz-utils \
    dosfstools \
    parted \
    ca-certificates \
    squashfs-tools \
    binutils \
    rsync \
    gnupg
apt-get clean
rm -rf /var/lib/apt/lists/*
EOFDOCKER

# === Target rootfs build ===
# This stage builds the target root filesystem
FROM rootfs-builder AS targetfs-build

WORKDIR /build
ENV ROOTFS_DIR="/rootfs"
ENV MMDEBSTRAP_VARIANT="apt"
#ENV MMDEBSTRAP_INCLUDE="systemd-sysv,systemd-boot,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree"
ENV MMDEBSTRAP_INCLUDE="zstd,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree,systemd-sysv,systemd-boot,live-boot"
COPY /boot/ /config/boot/
COPY /debstrap/target-hooks/ /hooks/
COPY /scripts/build-rootfs.sh /scripts/build-rootfs.sh

RUN --security=insecure \
    echo "=== Building TARGET rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    /scripts/build-rootfs.sh

RUN echo "=== Squashing target filesystem ===" && \
    mkdir -p ${OUTPUT_DIR} && \
    mksquashfs /rootfs ${OUTPUT_DIR}/rootfs.squashfs -comp xz -no-xattrs -no-fragments -wildcards -b 1M

FROM scratch AS targetfs-artifact

COPY --from=targetfs-build /output/ /

## FROM rootfs-builder AS boot-builder
## 
## WORKDIR /build
## ENV ROOTFS_DIR="/rootfs"
## ENV MMDEBSTRAP_VARIANT="apt"
## #ENV MMDEBSTRAP_INCLUDE="systemd-sysv,systemd-boot,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree"
## ENV MMDEBSTRAP_INCLUDE="xz-utils,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree,systemd-sysv,systemd-boot,live-boot"
## COPY /debstrap/target-hooks/ /hooks/
## COPY /scripts/build-rootfs.sh /scripts/build-rootfs.sh
## 
## RUN --security=insecure \
##     echo "=== Building TARGET rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
##     /scripts/build-rootfs.sh
## 
## RUN echo "=== Squashing target filesystem ===" && \
##     mksquashfs /rootfs ${OUTPUT_DIR}/rootfs.squashfs -comp xz -no-xattrs -no-fragments -wildcards -b 1M


# === EFI build ===
# This stage builds the EFI partition image
FROM base-builder AS efi-build

ARG EFI_DIR="/efi"
ARG EFI_TARGET_MOUNT_POINT="/efimount-target"
ARG EFI_MOUNT_POINT="/efimount"

WORKDIR /build

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists <<EOFDOCKER
set -eux
apt-get update
apt-get install -y --no-install-recommends \
    dosfstools
apt-get clean
rm -rf /var/lib/apt/lists/*
EOFDOCKER

# Make the EFI patition image
COPY --from=targetfs-build ${OUTPUT_DIR}/efi.img target-efi.img
COPY /boot/ ./boot/
RUN --security=insecure <<EOFDOCKER
set -eux
mkdir -p ${OUTPUT_DIR}
# Mount the target EFI partition
mkdir -p "${EFI_TARGET_MOUNT_POINT}"
mount -o loop target-efi.img "${EFI_TARGET_MOUNT_POINT}"
# Create a new EFI filesystem image
dd if=/dev/zero of="${OUTPUT_DIR}/efi.img" bs=1M count=10
mkfs.vfat -F 32 "${OUTPUT_DIR}/efi.img"
# Mount the EFI filesystem image
mkdir -p "${EFI_MOUNT_POINT}"
mount -o loop "${OUTPUT_DIR}/efi.img" "${EFI_MOUNT_POINT}"
# Copy the EFI files to the EFI filesystem image
cp -a ${EFI_TARGET_MOUNT_POINT}/EFI ${EFI_MOUNT_POINT}/EFI
cp -a ./boot ${EFI_MOUNT_POINT}/loader
# Copy the kernel and initrd to the output directory
cp -a ${EFI_TARGET_MOUNT_POINT}/vmlinuz-* ${OUTPUT_DIR}/vmlinuz
cp -a ${EFI_TARGET_MOUNT_POINT}/initrd.img-* ${OUTPUT_DIR}/initrd.img
# Unmount the EFI filesystem image
umount "${EFI_MOUNT_POINT}"
umount "${EFI_TARGET_MOUNT_POINT}"
EOFDOCKER

# === ISO build ===
# This stage builds the grub images and the final bootable ISO
FROM base-builder AS iso-build

ARG ISO_FILENAME
ARG ISO_LABEL="WHISTLEKUBE_ISO"
ARG ISO_APPID="Whistlekube Installer"
ARG ISO_PUBLISHER="Whistlekube"
ARG ISO_PREPARER="Built with xorriso"

ENV ISO_DIR="/iso"
ENV REPO_BINARY_DIR="${ISO_DIR}/pool/main/binary-${DEBIAN_ARCH}"
ENV REPO_DIST_DIR="${ISO_DIR}/dists/${DEBIAN_RELEASE}/main/binary-${DEBIAN_ARCH}"

RUN <<EOFDOCKER
set -eux
apt-get update
apt-get install -y --no-install-recommends \
    xorriso \
    dosfstools \
    apt-utils \
    xz-utils
apt-get clean
rm -rf /var/lib/apt/lists/*
EOFDOCKER

COPY --from=targetfs-build /output/rootfs.squashfs ${ISO_DIR}/live/filesystem.squashfs
COPY --from=efi-build ${OUTPUT_DIR}/efi.img /efi.img
COPY --from=efi-build ${OUTPUT_DIR}/vmlinuz ${ISO_DIR}/vmlinuz
COPY --from=efi-build ${OUTPUT_DIR}/initrd.img ${ISO_DIR}/initrd.img
RUN mkdir -p ${OUTPUT_DIR} && \
    xorriso \
    -as mkisofs \
    -iso-level 3 \
    -rock --joliet --joliet-long \
    --full-iso9660-filenames \
    -volid "${ISO_LABEL}" \
    -append_partition 2 0xEF /efi.img \
    -e --interval:appended_partition_2:all:: \
    -no-emul-boot \
    -appended_part_as_gpt \
    -output ${OUTPUT_DIR}/${ISO_FILENAME} \
    ${ISO_DIR}

##    -eltorito-alt-boot \
##    -e /EFI/BOOT/BOOTX64.EFI \
##    -no-emul-boot \
##    -boot-load-size 4 \
##    -boot-info-table \

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
