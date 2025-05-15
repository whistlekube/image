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
    mkdir -p /output /build/chroot   

WORKDIR /build

# Run debootstrap to create the minimal Debian system
# This will be cached by Docker for future builds
RUN echo "=== Debootstraping target rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    debootstrap --arch="${DEBIAN_ARCH}" \
                --variant=minbase \
                --include=systemd,systemd-sysv,dash,coreutils,util-linux \
                "${DEBIAN_RELEASE}" \
                ./target-rootfs \
                "${DEBIAN_MIRROR}" && \
    echo "=== Debootstraping live rootfs for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    debootstrap --arch="${DEBIAN_ARCH}" \
                --variant=minbase \
                "${DEBIAN_RELEASE}" \
                ./live-rootfs \
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
COPY /chroot-target/install.sh /build/target-rootfs/install.sh
COPY /scripts/chroot-install.sh /build/chroot-install.sh
RUN --security=insecure \
    echo "=== Configuring target chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    mount -t proc proc target-rootfs/proc && \
    mount -t sysfs sysfs target-rootfs/sys && \
    mount --bind /dev target-rootfs/dev && \
    mkdir -p target-rootfs/dev/pts && \
    mount --bind /dev/pts target-rootfs/dev/pts && \
    mount -t tmpfs shm target-rootfs/dev/shm && \
    cp /etc/resolv.conf target-rootfs/etc/resolv.conf && \
    cp /scripts/configure-chroot.sh target-rootfs/configure-chroot.sh && \
    chmod +x target-rootfs/configure-chroot.sh && \
    chroot target-rootfs /configure-chroot.sh || true && \
    rm -f target-rootfs/configure-chroot.sh && \
    umount -l target-rootfs/dev/shm && \
    umount -l target-rootfs/dev/pts && \
    umount -l target-rootfs/dev && \
    umount -l target-rootfs/sys && \
    umount -l target-rootfs/proc && \
    echo "=== Chroot configured ==="


# Setup live chroot environment, run configure-chroot.sh, and clean up
COPY /chroot-live/ /build/live-rootfs/
RUN --security=insecure \
    echo "=== Configuring live chroot for ${DEBIAN_ARCH} on ${DEBIAN_RELEASE} ===" && \
    mkdir -p 
    mount -t proc proc /build/live-rootfs/proc && \
    mount -t sysfs sysfs /build/live-rootfs/sys && \
    mount --bind /dev /build/live-rootfs/dev && \
    mkdir -p /build/live-rootfs/dev/pts && \
    mount --bind /dev/pts /build/live-rootfs/dev/pts && \
    mount -t tmpfs shm /build/live-rootfs/dev/shm && \
    cp /etc/resolv.conf /build/live-rootfs/etc/resolv.conf && \
    cp /scripts/configure-chroot.sh /build/live-rootfs/configure-chroot.sh && \
    chmod +x /build/live-rootfs/configure-chroot.sh && \
    chroot /build/live-rootfs /configure-chroot.sh || true && \
    rm -f /build/live-rootfs/configure-chroot.sh && \
    umount -l /build/live-rootfs/dev/shm && \
    umount -l /build/live-rootfs/dev/pts && \
    umount -l /build/live-rootfs/dev && \
    umount -l /build/live-rootfs/sys && \
    umount -l /build/live-rootfs/proc && \
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
RUN cp /build/live-rootfs/boot/vmlinuz-* /build/vmlinuz && \
    cp /build/live-rootfs/boot/initrd.img-* /build/initrd.img

# Set entrypoint to the build script
ENTRYPOINT ["/scripts/build-iso.sh"]

# Default command (can be overridden)
CMD ["BUILD_VERSION=latest", "ISO_FILENAME=whistlekube-installer.iso"]


FROM scratch AS artifact
COPY --from=builder /output/whistlekube-installer.iso /whistlekube-installer.iso

## RUN mkdir -p /scripts /config /output
## 
## 
## # Install required packages in a single RUN instruction to reduce layers
## RUN apt-get update && \
##     apt-get install -y --no-install-recommends \
##         debootstrap \
##         xorriso \
##         isolinux \
##         syslinux-common \
##         syslinux-utils \
##         cpio \
##         genisoimage \
##         dosfstools \
##         squashfs-tools \
##         mtools \
##         binutils \
##         ca-certificates \
##         curl \
##         gnupg \
##         rsync \
##         sudo \
##         systemd-container \
##         xz-utils \
##         file \
##         bzip2 \
##         less \
##         grub-common \
##         grub-efi-amd64-bin \
##         grub-pc-bin \
##         grub2-common \
##         kpartx \
##         parted \
##         gdisk && \
##     apt-get clean && \
##     rm -rf /var/lib/apt/lists/*
## 
## # Create a policy file to prevent services from starting in the container
## RUN echo "#!/bin/sh\nexit 101" > /usr/sbin/policy-rc.d && \
##     chmod +x /usr/sbin/policy-rc.d
## 
## # Copy scripts and configuration files
## COPY scripts/ /scripts/
## COPY config/ /config/
## 
## # Make scripts executable
## RUN chmod +x /scripts/*.sh
## 
## # Run debootstrap to create a minimal Debian system
## RUN debootstrap --arch=amd64 --variant=minbase --include=systemd-sysv trixie /build/chroot http://deb.debian.org/debian
## 
## # Set entrypoint to the build script
## ENTRYPOINT ["/scripts/build-iso.sh"]
## 
## # Default command (can be overridden)
## CMD ["BUILD_VERSION=latest", "ISO_FILENAME=whistlekube-installer.iso"]
