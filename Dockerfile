# syntax=docker/dockerfile:1-labs

# Global build arguments
ARG DEBIAN_RELEASE="trixie"
ARG BUILD_VERSION="UNKNOWNVERSION"
ARG DEBIAN_MIRROR="http://deb.debian.org/debian"
ARG ISO_FILENAME="whistlekube-installer-${BUILD_VERSION}.iso"
ARG OUTPUT_DIR="/output"
ARG K3S_VERSION="v1.33.0+k3s1"


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

# === Download k3s ===
FROM base-builder AS k3s-download

ARG K3S_VERSION
ARG DEBIAN_ARCH

# Install curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl openssl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${OUTPUT_DIR} && \
    curl -fSL -o ${OUTPUT_DIR}/k3s "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s" && \
    curl -fSL -o ${OUTPUT_DIR}/k3s-airgap-images-${DEBIAN_ARCH}.tar.gz \
    "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-${DEBIAN_ARCH}.tar.gz" && \
    chmod +x ${OUTPUT_DIR}/k3s

# === Base rootfs builder with tools installed ===
# This stage builds the base chroot environment that is used for both the target and live root filesystems
FROM base-builder AS rootfs-builder
# Install required packages for the build process
# Then run mmdebstrap to create the minimal Debian system
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists <<EOFDOCKER
set -eux
apt-get update
apt-get install -y --no-install-recommends \
    mmdebstrap \
    squashfs-tools \
    ca-certificates
apt-get clean
rm -rf /var/lib/apt/lists/*
EOFDOCKER
ENV ROOTFS_DIR="/rootfs"

# === Installer rootfs build ===
# This stage builds the installer root filesystem
FROM rootfs-builder AS installer-debstrap
ENV MMDEBSTRAP_VARIANT="essential"
ENV MMDEBSTRAP_INCLUDE="\
    zstd,live-boot,live-config-systemd,\
    linux-image-amd64,firmware-linux-free,firmware-linux-nonfree,\
    systemd-sysv,bash,coreutils,dialog,squashfs-tools,parted,gdisk,e2fsprogs,\
    lvm2,cryptsetup,dosfstools,ca-certificates,\
    grub-common,grub-efi-amd64-bin,grub-efi-amd64-signed,grub-pc-bin"
COPY /scripts/build-rootfs.sh /scripts/build-rootfs.sh
RUN --security=insecure \
    echo "=== Building INSTALLER rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    /scripts/build-rootfs.sh && \
    mkdir -p ${OUTPUT_DIR} && \
    cp ${ROOTFS_DIR}/boot/vmlinuz-* ${OUTPUT_DIR}/vmlinuz && \
    cp ${ROOTFS_DIR}/boot/initrd.img-* ${OUTPUT_DIR}/initrd.img

# === Configure the installer rootfs ===
FROM installer-debstrap AS installer-configure
COPY /installer/overlay/ ${ROOTFS_DIR}/
COPY /installer/configure-chroot.sh ${ROOTFS_DIR}/configure-chroot.sh
COPY /scripts/mount-chroot.sh /scripts/mount-chroot.sh
COPY /scripts/umount-chroot.sh /scripts/umount-chroot.sh
RUN --security=insecure <<EOFDOCKER
set -eux
echo "=== Configuring INSTALLER rootfs ==="
/scripts/mount-chroot.sh
chroot ${ROOTFS_DIR} /configure-chroot.sh
/scripts/umount-chroot.sh
rm -f ${ROOTFS_DIR}/configure-chroot.sh
EOFDOCKER

# === Build the installer squashfs ===
FROM installer-configure AS installer-build
RUN echo "=== Squashing INSTALLER filesystem ===" && \
    mkdir -p ${OUTPUT_DIR} && \
    mksquashfs /rootfs ${OUTPUT_DIR}/installer.squashfs -comp zstd -no-xattrs -no-fragments -wildcards -b 1M

# === Installer rootfs artifact ===
FROM scratch AS installer-artifact
COPY --from=installer-build /output/ /

# === Target rootfs build ===
# This stage builds the target root filesystem
FROM rootfs-builder AS target-debstrap
WORKDIR /build
ENV ROOTFS_DIR="/rootfs"
ENV MMDEBSTRAP_VARIANT="apt"
#ENV MMDEBSTRAP_INCLUDE="systemd-sysv,systemd-boot,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree"
ENV MMDEBSTRAP_INCLUDE="zstd,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree,\
    systemd-sysv,passwd,util-linux,coreutils,dbus,libpam-systemd,login,bash,ca-certificates"
#COPY /boot/ /config/boot/
COPY /scripts/build-rootfs.sh /scripts/build-rootfs.sh
RUN --security=insecure \
    echo "=== Building TARGET rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    mkdir -p ${OUTPUT_DIR} && \
    /scripts/build-rootfs.sh

# === Configure the target rootfs ===
FROM target-debstrap AS target-configure
COPY /target/overlay/ ${ROOTFS_DIR}/
COPY --from=k3s-download ${OUTPUT_DIR}/k3s ${ROOTFS_DIR}/usr/local/bin/k3s
COPY /target/configure-chroot.sh ${ROOTFS_DIR}/configure-chroot.sh
COPY /scripts/mount-chroot.sh /scripts/mount-chroot.sh
COPY /scripts/umount-chroot.sh /scripts/umount-chroot.sh
RUN --security=insecure <<EOFDOCKER
set -eux
echo "=== Configuring TARGET rootfs ==="
/scripts/mount-chroot.sh
chroot ${ROOTFS_DIR} /configure-chroot.sh
/scripts/umount-chroot.sh
rm -f ${ROOTFS_DIR}/configure-chroot.sh
EOFDOCKER

# === Build the target squashfs ===
FROM target-configure AS target-build
RUN echo "=== Squashing TARGET filesystem ===" && \
    mkdir -p ${OUTPUT_DIR} && \
    mksquashfs /rootfs ${OUTPUT_DIR}/rootfs.squashfs -comp zstd -no-xattrs -no-fragments -wildcards -b 1M

# === Target rootfs artifact ===
FROM scratch AS target-artifact
COPY --from=target-build /output/ /

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

RUN <<EOFDOCKER
set -eux
apt-get update
apt-get install -y --no-install-recommends \
    dosfstools \
    grub-common \
    grub-efi-amd64-bin \
    grub-efi-amd64-signed \
    grub-pc-bin
apt-get clean
rm -rf /var/lib/apt/lists/*
EOFDOCKER

# Make the EFI patition image
COPY /installer/grub.cfg /config/grub.cfg
#COPY /boot/loader/ /efi/loader/
#COPY --from=installerfs-build /rootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi /efi/EFI/BOOT/BOOTX64.EFI
#COPY --from=installerfs-build /rootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi /efi/EFI/systemd/systemd-bootx64.efi
RUN --security=insecure <<EOFDOCKER
set -eux
mkdir -p ${OUTPUT_DIR}
# Create a new EFI filesystem image
dd if=/dev/zero of="${OUTPUT_DIR}/efi.img" bs=1M count=20
mkdir -p "${EFI_MOUNT_POINT}"
mkfs.fat -F 12 -n "UEFI_BOOT" "${OUTPUT_DIR}/efi.img"
# Mount the EFI filesystem image
mount -o loop "${OUTPUT_DIR}/efi.img" "${EFI_MOUNT_POINT}"
#cp -r /efi/* "${EFI_MOUNT_POINT}"
#find "${EFI_MOUNT_POINT}"
# Copy the EFI files to the EFI filesystem image
grub-mkstandalone \
    -O x86_64-efi \
    -o "${OUTPUT_DIR}/grub.efi" \
    --modules "iso9660 normal configfile echo linux search search_label part_msdos part_gpt fat ext2 efi_gop efi_uga all_video font" \
    --locales "" \
    --themes "" \
    "/boot/grub/grub.cfg=/config/grub.cfg"
# Copy the grub.efi to the EFI filesystem image
mkdir -p "${EFI_MOUNT_POINT}/EFI/BOOT"
cp "${OUTPUT_DIR}/grub.efi" "${EFI_MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI"
# Unmount the EFI filesystem image
umount "${EFI_MOUNT_POINT}"

# Make grub core image
grub-mkimage \
    -O i386-pc-eltorito \
    -o "${OUTPUT_DIR}/core.img" \
    -p /boot/grub \
    biosdisk iso9660 \
    normal configfile \
    echo linux search search_label \
    part_msdos part_gpt fat ext2
EOFDOCKER

FROM scratch AS efi-artifact
ARG OUTPUT_DIR
COPY --from=efi-build ${OUTPUT_DIR} /

# === ISO build ===
# This stage builds the grub images and the final bootable ISO
FROM base-builder AS iso-build-tools

RUN <<EOFDOCKER
set -eux
apt-get update
apt-get install -y --no-install-recommends \
    xorriso \
    grub-pc-bin \
    xz-utils
apt-get clean
rm -rf /var/lib/apt/lists/*
EOFDOCKER

FROM iso-build-tools AS iso-build

ARG ISO_FILENAME
ARG ISO_LABEL="WHISTLEKUBE_ISO"
ARG ISO_APPID="Whistlekube Installer"
ARG ISO_PUBLISHER="Whistlekube"
ARG ISO_PREPARER="Built with xorriso"

ENV ISO_DIR="/iso"
ENV REPO_BINARY_DIR="${ISO_DIR}/pool/main/binary-${DEBIAN_ARCH}"
ENV REPO_DIST_DIR="${ISO_DIR}/dists/${DEBIAN_RELEASE}/main/binary-${DEBIAN_ARCH}"
ENV HYBRID_MBR_PATH="/usr/lib/grub/i386-pc/boot_hybrid.img"

COPY --from=installer-build ${OUTPUT_DIR}/vmlinuz ${ISO_DIR}/live/vmlinuz
COPY --from=installer-build ${OUTPUT_DIR}/initrd.img ${ISO_DIR}/live/initrd.img
COPY --from=installer-build ${OUTPUT_DIR}/installer.squashfs ${ISO_DIR}/live/filesystem.squashfs
COPY --from=target-build ${OUTPUT_DIR}/rootfs.squashfs ${ISO_DIR}/install/filesystem.squashfs
#COPY --from=initrd-build /initrd-live.img ${ISO_DIR}/live/initrd.img
COPY /installer/grub.cfg ${ISO_DIR}/boot/grub/grub.cfg
COPY --from=efi-build ${OUTPUT_DIR}/efi.img ${ISO_DIR}/boot/grub/efi.img
COPY --from=efi-build ${OUTPUT_DIR}/core.img ${ISO_DIR}/boot/grub/core.img
COPY --from=efi-build ${OUTPUT_DIR}/grub.efi ${ISO_DIR}/EFI/BOOT/BOOTX64.EFI
COPY /scripts/build-iso.sh /scripts/build-iso.sh

RUN --security=insecure \
    mkdir -p ${OUTPUT_DIR} && \
    xorriso \
      -as mkisofs \
      -iso-level 3 \
      -rock --joliet --joliet-long \
      -full-iso9660-filenames \
      -volid "${ISO_LABEL}" \
      -appid "${ISO_APPID}" \
      -publisher "${ISO_PUBLISHER}" \
      -preparer "${ISO_PREPARER}" \
      -c boot.catalog \
      -eltorito-boot boot/grub/core.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
      -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
      -isohybrid-mbr ${HYBRID_MBR_PATH} \
      -isohybrid-gpt-basdat \
      -output "${OUTPUT_DIR}/${ISO_FILENAME}" \
      "${ISO_DIR}"

## RUN mkdir -p ${OUTPUT_DIR} && \
##     xorriso \
##     -as mkisofs \
##     -iso-level 3 \
##     -rock --joliet --joliet-long \
##     --full-iso9660-filenames \
##     -volid "${ISO_LABEL}" \
##     -eltorito-boot boot/grub/core.img \
##       -no-emul-boot \
##       -boot-load-size 4 \
##       -boot-info-table \
##       --grub2-boot-info \
##     -eltorito-alt-boot \
##       -e EFI/efiboot.img \
##       -no-emul-boot \
##     -append_partition 2 0xef ${ISO_DIR}/EFI/efiboot.img \
##     -isohybrid-mbr ${HYBRID_MBR_PATH} \
##     -isohybrid-gpt-basdat \
##     -output ${OUTPUT_DIR}/${ISO_FILENAME} \
##     ${ISO_DIR}

##    -partition_offset 16 \
##    -c boot.catalog \
##    -eltorito-alt-boot \
##    -e --interval:appended_partition_2:all:: \
##    -no-emul-boot \
##    -append_partition 2 0xEF /efi.img \
##    -appended_part_as_gpt \
##    -isohybrid-gpt-basdat \

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
