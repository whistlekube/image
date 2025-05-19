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
    systemd-boot \
    systemd-ukify \
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

#--customize-hook='echo "root:x:0:0:root:/root:/bin/sh" > "$1/etc/passwd"' \
#--customize-hook='echo "root:x:0:" > "$1/etc/group"' \
#--customize-hook='mkdir -p "$1/run" "$1/proc" "$1/sys" "$1/dev"' \
#--hook-dir=/usr/share/mmdebstrap/hooks/busybox \

## # Environment variables for ukify
## ENV UKIFY_EFI_CMDLINE="\
##     boot=live \
##     root=LABEL=WHISTLEKUBE_ISO \
##     components \
##     splash \
##     nomodeset \
##     autologin \
##     username=root \
##     hostname=whistlekube-installer \
##     locales=en_US.UTF-8 \
##     keyboard-layouts=us"
## 
## # === Target boot environment build ===
## # This stage builds the target boot environment (initramfs, kernel, uki)
## FROM rootfs-builder AS targetboot-build
## WORKDIR /build
## ENV MMDEBSTRAP_VARIANT="apt"
## ENV MMDEBSTRAP_INCLUDE="systemd-sysv,systemd-boot,linux-image-amd64,squashfs-tools,dracut,dracut-live,dracut-config-generic"
## COPY /debstrap/targetboot-hooks/ /hooks/
## COPY /debstrap/targetboot-preoverlay/ /preoverlay/
## COPY /scripts/build-rootfs.sh /scripts/build-rootfs.sh
## RUN --security=insecure <<EOFDOCKER
##     echo "=== Building TARGET boot environment for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ==="
##     /scripts/build-rootfs.sh
## EOFDOCKER

## # === Debstrap build ===
## # This stage builds the target root filesystem
## FROM rootfs-builder AS debstrap-build
## 
## WORKDIR /build
## ENV ROOTFS_DIR="/rootfs"
## ENV MMDEBSTRAP_VARIANT="apt"
## #ENV MMDEBSTRAP_INCLUDE="systemd-sysv,systemd-boot,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree"
## ENV MMDEBSTRAP_INCLUDE="systemd-sysv,systemd-boot,dracut,dracut-live,dracut-config-generic,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree"
## COPY /debstrap/target-hooks/ /hooks/
## COPY /scripts/build-rootfs.sh /scripts/build-rootfs.sh
## COPY /debstrap/dracut.conf .
## 
## RUN --security=insecure \
##     echo "=== Building TARGET rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
##     /scripts/build-rootfs.sh

# === Target rootfs build ===
# This stage builds the target root filesystem
FROM rootfs-builder AS targetfs-build

WORKDIR /build
ENV ROOTFS_DIR="/rootfs"
ENV MMDEBSTRAP_VARIANT="apt"
#ENV MMDEBSTRAP_INCLUDE="systemd-sysv,systemd-boot,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree"
ENV MMDEBSTRAP_INCLUDE="systemd-sysv,xz-utils,systemd-boot,live-boot,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree"
COPY /debstrap/target-hooks/ /hooks/
COPY /scripts/build-rootfs.sh /scripts/build-rootfs.sh
COPY /debstrap/dracut.conf .

RUN --security=insecure \
    echo "=== Building TARGET rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    /scripts/build-rootfs.sh

RUN echo "=== Squashing target filesystem ===" && \
    mksquashfs /rootfs "/rootfs.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M

#FROM rootfs-builder AS targetboot-build
#
#ENV ROOTFS_DIR="/rootfs"
#ENV MMDEBSTRAP_VARIANT="apt"
#ENV MMDEBSTRAP_INCLUDE="systemd-sysv,systemd-boot,live-boot,linux-image-amd64,xz-utils,firmware-linux-free,firmware-linux-nonfree"
#COPY /debstrap/targetboot-hooks/ /hooks/
#COPY /scripts/build-rootfs.sh /scripts/build-rootfs.sh
#COPY /debstrap/targetboot-overlay/ /overlay/
#COPY /debstrap/dracut.conf /dracut.conf
#RUN --security=insecure \
#    echo "=== Building TARGET boot environment chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
#    /scripts/build-rootfs.sh


## # === Installer rootfs build ===
## FROM rootfs-builder AS installerfs-build
## 
## WORKDIR /build
## ENV ROOTFS_DIR="/rootfs"
## ENV MMDEBSTRAP_VARIANT="apt"
## ENV MMDEBSTRAP_INCLUDE="systemd-sysv,systemd-boot,linux-image-amd64,firmware-linux-free,firmware-linux-nonfree"
## COPY /debstrap/installer-hooks/ /hooks/
## COPY /scripts/build-rootfs.sh /scripts/build-rootfs.sh
## 
## RUN --security=insecure \
##     echo "=== Building INSTALLER rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
##     /scripts/build-rootfs.sh
## 
## RUN echo "=== Squashing installer filesystem ===" && \
##     mksquashfs /rootfs "/rootfs.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M

## # === EFI build ===
## # This stage builds the EFI file containing the kernel and initramfs
## FROM targetfs-build AS efi-build
## 
## WORKDIR /work
## ENV ROOTFS_DIR="/rootfs"
## ENV MODULE_DIR="${ROOTFS_DIR}/usr/lib/modules/${KVER}/kernel/drivers/firmware"
## ENV FIRMWARE_DIR="${ROOTFS_DIR}/usr/lib/modules/${KVER}/kernel/drivers/firmware"
## #COPY /debstrap/dracut.conf /dracut.conf
## 
## ## RUN --security=insecure <<EOFDOCKER
## ## set -eux
## ## echo "=== Building TARGET initramfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ==="
## ## KVER=$(ls -1 $ROOTFS_DIR/usr/lib/modules | sort -V | tail -n1)
## ## ln -s ${ROOTFS_DIR}/boot/vmlinuz-${KVER} /boot/
## ## dracut \
## ##     --conf dracut.conf \
## ##     --kver ${KVER} \
## ##     --kmoddir ${ROOTFS_DIR}/usr/lib/modules/${KVER} \
## ##     --omit plymouth \
## ##     --no-hostonly \
## ##     --force \
## ##     /initrd.img
## ## EOFDOCKER
## #    --fwdir ${ROOTFS_DIR}/usr/lib/firmware \
## 
## FROM scratch AS targetfs-artifact
## COPY --from=targetfs-build /rootfs /rootfs
## COPY --from=targetfs-build /rootfs.squashfs /rootfs.squashfs


#ENV MMDEBSTRAP_INCLUDE="dpkg,busybox,systemd-boot,linux-image-amd64,grub-efi-amd64,grub-efi-amd64-signed,efibootmgr,squashfs-tools"
#ENV MMDEBSTRAP_INCLUDE="systemd-boot,linux-image-amd64,grub-efi-amd64,grub-efi-amd64-signed,efibootmgr,squashfs-tools"
#ARG MMDEBSTRAP_INCLUDE="dpkg,busybox,libc-bin,libc6,base-files,base-passwd,systemd-boot"
#ARG MMDEBSTRAP_INCLUDE="systemd-boot,linux-image-amd64,grub-efi-amd64,grub-efi-amd64-signed,efibootmgr,squashfs-tools"
#ARG MMDEBSTRAP_INCLUDE="systemd-boot,linux-image-amd64"
#RUN --security=insecure \
#    echo "=== Mmdebstrap TARGET rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
#    mmdebstrap --variant=${MMDEBSTRAP_VARIANT} \
#        --components=main,contrib,non-free,non-free-firmware \
#        --include=${MMDEBSTRAP_INCLUDE} \
#        --dpkgopt=path-exclude=/usr/share/man/* \
#        --dpkgopt=path-exclude=/usr/share/locale/* \
#        --dpkgopt=path-include=/usr/share/locale/locale.alias \
#        --dpkgopt=path-exclude=/usr/share/doc/* \
#        --dpkgopt=path-include=/usr/share/doc/*/copyright \
#        --hook-dir=/hooks \
#        ${DEBIAN_RELEASE} \
#        /rootfs \
#        ${DEBIAN_MIRROR} && \
#    echo "=== Building Unified Kernel Image ===" && \
#    mkdir -p /rootfs/boot/EFI/Linux && \
#    ukify build \
#        --linux=/rootfs/vmlinuz \
#        --initrd=/rootfs/initrd.img \
#        --cmdline="${UKIFY_EFI_CMDLINE}" \
#        --output=/rootfs/boot/EFI/Linux/whistlekube-a.efi && \
#    echo "=== Squashing target filesystem ===" && \
#    mksquashfs /rootfs "/filesystem.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M && \
#    echo "=== Chroot configured for target ==="

#--hook-dir=/usr/share/mmdebstrap/hooks/busybox \


# === Build initramfs and kernel ===
# This stage builds the target root filesystem
## FROM rootfs-builder AS boot-build
## ARG MMDEBSTRAP_VARIANT="minbase"
## ARG MMDEBSTRAP_INCLUDE="initramfs-tools"
## RUN --security=insecure <<EOFDOCKER
##     echo "=== Mmdebstrap boot builder for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ==="
##     mmdebstrap --variant=${MMDEBSTRAP_VARIANT} \
##         --include=${MMDEBSTRAP_INCLUDE} \
##         ${MMDEBSTRAP_NODOCS} \
##         ${DEBIAN_RELEASE} \
##         /rootfs \
##         ${DEBIAN_MIRROR}
##     echo "=== Mmdebstrap DONE ==="
## EOFDOCKER

# === Base chroot build ===
#FROM debootstrap-builder AS chroot-builder
## Copy the base overlay and run base bootstrap script
#COPY /overlays/base/ "${ROOTFS_DIR}/"
#RUN --mount=type=cache,target=${ROOTFS_DIR}/var/cache/apt,sharing=locked \
#    --mount=type=cache,target=${ROOTFS_DIR}/var/lib/apt,sharing=locked \
#    --security=insecure \
#    echo "=== Configuring base chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
#    chroot "${ROOTFS_DIR}" "${CHROOT_BOOTSTRAP_DIR}/bootstrap-base.sh" && \
#    echo "=== Chroot configured for base ==="

# === Target chroot build ===
# This stage builds the target chroot environment that is used for the target filesystem
# Outputs filesystem.squashfs binary
##FROM debootstrap-builder AS targetfs-build
##COPY /scripts/target-chroot.sh "${ROOTFS_DIR}/"
##RUN --security=insecure \
##    echo "=== Configuring target chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
##    mkdir -p "${ROOTFS_DIR}/proc" && \
##    mount -t proc proc "${ROOTFS_DIR}/proc" && \
##    mkdir -p "${ROOTFS_DIR}/sys" && \
##    mount -t sysfs sysfs "${ROOTFS_DIR}/sys" && \
##    mkdir -p "${ROOTFS_DIR}/dev" && \
##    mount --bind /dev "${ROOTFS_DIR}/dev" && \
##    mkdir -p "${ROOTFS_DIR}/dev/pts" && \
##    mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts" && \
##    mkdir -p "${ROOTFS_DIR}/dev/shm" && \
##    mount -t tmpfs shm "${ROOTFS_DIR}/dev/shm" && \
##    echo "=== Running target chroot script ===" && \
##    chroot "${ROOTFS_DIR}" "/target-chroot.sh" && \
##    echo "=== Cleaning up target chroot ===" && \
##    umount -l "${ROOTFS_DIR}/dev/shm" && \
##    umount -l "${ROOTFS_DIR}/dev/pts" && \
##    umount -l "${ROOTFS_DIR}/dev" && \
##    umount -l "${ROOTFS_DIR}/sys" && \
##    umount -l "${ROOTFS_DIR}/proc" && \
##    echo "=== Squashing target filesystem ===" && \
##    mkdir -p "${OUTPUT_DIR}" && \
##    mksquashfs "${ROOTFS_DIR}" "${OUTPUT_DIR}/filesystem.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M && \
##    echo "=== Chroot configured for target ==="

# === Live chroot build ===
# This stage builds the live chroot environment that is used for the live installer
# Outputs kernel, initrd, and filesystem.squashfs binaries
#FROM chroot-builder AS livefs-build
#
## Copy the live overlay and run live bootstrap script
#COPY /overlays/live/ "${ROOTFS_DIR}/"
#RUN --mount=type=cache,target=${ROOTFS_DIR}/var/cache/apt,sharing=locked \
#    --mount=type=cache,target=${ROOTFS_DIR}/var/lib/apt,sharing=locked \
#    --security=insecure \
#    echo "=== Configuring live chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
#    chroot "${ROOTFS_DIR}" "${CHROOT_BOOTSTRAP_DIR}/bootstrap-live.sh" && \
#    echo "=== Copying kernel and initrd from live chroot ===" && \
#    mkdir -p "${OUTPUT_DIR}" && \
#    cp ${ROOTFS_DIR}/boot/vmlinuz-* "${OUTPUT_DIR}/vmlinuz" && \
#    cp ${ROOTFS_DIR}/boot/initrd.img-* "${OUTPUT_DIR}/initrd.img" && \
#    echo "=== Cleaning up live chroot ===" && \
#    chroot "${ROOTFS_DIR}" "${CHROOT_BOOTSTRAP_DIR}/cleanup-live.sh" && \
#    rm -rf "${ROOTFS_DIR}${CHROOT_BOOTSTRAP_DIR}" && \
#    echo "=== Squashing live filesystem ===" && \
#    mksquashfs "${ROOTFS_DIR}" "${OUTPUT_DIR}/filesystem.squashfs" -comp xz -no-xattrs -no-fragments -wildcards -b 1M && \
#    echo "=== Chroot configured for live ==="

# Setup the apt repository directory
##RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
##    --mount=type=cache,target=/var/lib/apt,sharing=locked \
##    # Move packages to repo directory
##    mv *.deb ${APT_REPO_DIR}/ && \
##    # Create Packages file
##    cd ${APT_REPO_DIR} && \
##    apt-ftparchive packages . > Packages && \
##    gzip -k Packages && \
##    # Create Release file
##    cd .. && \
##    apt-ftparchive release binary > Release && \
##    apt-get clean && \
##    rm -rf /var/lib/apt/lists/*

# === ISO build ===
# This stage builds the grub images and the final bootable ISO
FROM base-builder AS iso-build

ARG ISO_FILENAME
ARG ISO_LABEL="WHISTLEKUBE_ISO"
ARG ISO_APPID="Whistlekube Installer"
ARG ISO_PUBLISHER="Whistlekube"
ARG ISO_PREPARER="Built with xorriso"

ENV ISO_DIR="/iso"
ENV EFI_DIR="/EFI"
ENV EFI_MOUNT_POINT="/efimount"
ENV REPO_BINARY_DIR="${ISO_DIR}/pool/main/binary-${DEBIAN_ARCH}"
ENV REPO_DIST_DIR="${ISO_DIR}/dists/${DEBIAN_RELEASE}/main/binary-${DEBIAN_ARCH}"

RUN <<EOFDOCKER
set -eux
apt-get update
apt-get install -y --no-install-recommends \
    xorriso \
    dosfstools \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub2-common \
    apt-utils \
    xz-utils
apt-get clean
rm -rf /var/lib/apt/lists/*
EOFDOCKER

# Make the EFI patition image
COPY --from=targetboot-build /rootfs/vmlinuz ${ISO_DIR}/vmlinuz
COPY --from=targetboot-build /rootfs/initrd.img ${ISO_DIR}/initrd.img
COPY --from=efi-build /initrd.img ${ISO_DIR}/initrd.img
COPY --from=efi-build /usr/lib/systemd/boot/efi/systemd-bootx64.efi ${EFI_DIR}/EFI/BOOT/BOOTX64.EFI
COPY --from=efi-build /usr/lib/systemd/boot/efi/systemd-bootx64.efi ${ISO_DIR}/EFI/BOOT/BOOTX64.EFI
COPY /boot/ ${EFI_DIR}/loader/
RUN --security=insecure <<EOFDOCKER
    set -eux
    dd if=/dev/zero of="/efiboot.img" bs=1M count=10
    mkfs.vfat -F 32 /efiboot.img
    mkdir -p "${EFI_MOUNT_POINT}"
    mount -o loop /efiboot.img "${EFI_MOUNT_POINT}"
    cp -a "${EFI_DIR}"/* "${EFI_MOUNT_POINT}/"
    umount "${EFI_MOUNT_POINT}"
EOFDOCKER

COPY --from=targetfs-build /rootfs.squashfs ${ISO_DIR}/live/filesystem.squashfs
RUN mkdir -p ${OUTPUT_DIR} && \
    xorriso \
    -as mkisofs \
    -iso-level 3 \
    -rock --joliet --joliet-long \
    -volid "${ISO_LABEL}" \
    -eltorito-alt-boot \
    -e /EFI/BOOT/BOOTX64.EFI \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -output ${OUTPUT_DIR}/${ISO_FILENAME} \
    ${ISO_DIR}

#    -boot-catalog /boot.cat \
#    -full-iso9660-filenames \
#    -appid "${ISO_APPID}" \
#    -publisher "${ISO_PUBLISHER}" \
#    -preparer "${ISO_PREPARER}" \
##    -partition_offset 16 \
#    -append_partition 2 0xef "${ISO_DIR}/EFI/efiboot.img" \
#    -graft-points \
#        EFI=EFI \
#        loader=loader \
#        linux.efi=linux.efi \


# Install required packages for the build process
# and build the local installer repository
#COPY --from=targetfs-build /rootfs.squashfs ${ISO_DIR}/rootfs.squashfs
#COPY --from=initramfs-artifact /initramfs.img ${ISO_DIR}/initramfs.img
#RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
#    --mount=type=cache,target=/var/lib/apt,sharing=locked \
#    apt-get update -y && \
#    apt-get install -y --no-install-recommends \
#        grub-pc-bin \
#        grub-efi-amd64-bin \
#        grub2-common \
#        apt-utils \
#        xz-utils \
#        xorriso \
#        cpio \
#        genisoimage \
#        dosfstools \
#        mtools && \
#    apt-get clean && \
#    rm -rf /var/lib/apt/lists/*

#RUN <<EOFDOCKER
#    echo "=== Building local installer repository ===" && \
#    mkdir -p "${REPO_BINARY_DIR}" "${REPO_DIST_DIR}" && \
#    cd "${ISO_DIR}" && \
#    apt-ftparchive packages pool/main > "${REPO_DIST_DIR}/Packages" && \
#    gzip -k "${REPO_DIST_DIR}/Packages" && \
#    apt-ftparchive release dists/trixie/main > "${REPO_DIST_DIR}/Release" && \
#    echo "********* PACKAGES *********" && \
#    cat "${REPO_DIST_DIR}/Packages.gz" | gunzip && \
#    echo "********* RELEASE *********" && \
#    cat "${REPO_DIST_DIR}/Release" && \
#    apt-get clean && \
#    rm -rf /var/lib/apt/lists/*
#EOFDOCKER

##### # Copy the kernel, initrd, and squashfs files from the chroot builders
##### COPY --from=livefs-build ${OUTPUT_DIR}/filesystem.squashfs ${ISO_DIR}/live/filesystem.squashfs
##### COPY --from=livefs-build ${OUTPUT_DIR}/vmlinuz ${ISO_DIR}/live/vmlinuz
##### COPY --from=livefs-build ${OUTPUT_DIR}/initrd.img ${ISO_DIR}/live/initrd.img
##### COPY --from=targetfs-build ${OUTPUT_DIR}/filesystem.squashfs ${ISO_DIR}/install/filesystem.squashfs
##### # Copy the ISO overlay files
##### COPY /overlays/iso/ ${ISO_DIR}/
##### # Copy the ISO build script
##### COPY /scripts/build-iso.sh .
##### 
##### ARG ISO_LABEL="WHISTLEKUBE_ISO"
##### ARG ISO_APPID="Whistlekube Installer"
##### ARG ISO_PUBLISHER="Whistlekube"
##### ARG ISO_PREPARER="Built with xorriso"
##### ARG ISO_FILENAME
##### 
##### ENV ISO_EFI_DIR="${ISO_DIR}/EFI"
##### ENV EFI_MOUNT_POINT="/efimount"
##### 
##### # Build the GRUB images for BIOS and EFI boot and the final ISO
##### RUN --security=insecure \
#####     ./build-iso.sh

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
