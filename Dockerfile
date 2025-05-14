# Use a Debian trixie base image
FROM debian:trixie-slim

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

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

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
        gdisk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Determine which architecture to use
RUN echo "Target architecture: ${TARGETARCH}"

# Create directories for scripts, config, and output
WORKDIR /build
RUN mkdir -p /scripts /config /output /build/chroot

# Run debootstrap to create the minimal Debian system
# This will be cached by Docker for future builds
COPY config/ /config/
RUN DEBIAN_ARCH="${TARGETARCH}"; \
    if [ "${TARGETARCH}" = "arm" ]; then \
        DEBIAN_ARCH="armhf"; \
    fi; \
    debootstrap --arch="${DEBIAN_ARCH}" \
                --variant=minbase \
                --include=systemd,systemd-sysv,bash,coreutils,util-linux \
                "${DEBIAN_RELEASE}" \
                /build/chroot \
                "${DEBIAN_MIRROR}"

# Debug: Check what's in the chroot
RUN echo "=== Contents of /build/chroot ===" && \
    ls -la /build/chroot && \
    echo "=== Contents of /build/chroot/bin ===" && \
    ls -la /build/chroot/bin || echo "No bin directory found" && \
    echo "=== Contents of /build/chroot/usr/bin ===" && \
    ls -la /build/chroot/usr/bin || echo "No usr/bin directory found"

RUN echo "Debootstrap DONE"

# Set up policy to prevent services from starting
RUN echo "#!/bin/sh\nexit 101" > /build/chroot/usr/sbin/policy-rc.d && \
    chmod +x /build/chroot/usr/sbin/policy-rc.d

## # Mount essential filesystems for chroot
## RUN mount -t proc proc /build/chroot/proc && \
##     mount -t sysfs sysfs /build/chroot/sys && \
##     mount --bind /dev /build/chroot/dev && \
##     mkdir -p /build/chroot/dev/pts && \
##     mount --bind /dev/pts /build/chroot/dev/pts
## 
## # Copy DNS resolver settings
## RUN cp /etc/resolv.conf /build/chroot/etc/resolv.conf
## 
## # Execute the configuration script inside the chroot
## RUN chroot /build/chroot /configure-chroot.sh
## 
## # Unmount chroot file systems
## RUN umount -l /build/chroot/dev/pts && \
##     umount -l /build/chroot/dev && \
##     umount -l /build/chroot/sys && \
##     umount -l /build/chroot/proc
## 
## # Clean up the chroot
## RUN rm -f /build/chroot/configure-chroot.sh && \
##     rm -f /build/chroot/packages.list



# Stage 2: Final build environment
# FROM builder as stage-debootstrap-done

# Install required packages for ISO building
# Set environment variables
# ENV DEBIAN_FRONTEND=noninteractive \
#     DEBCONF_NONINTERACTIVE_SEEN=true \
#     PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Copy scripts and make them executable
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Set entrypoint to the build script
ENTRYPOINT ["/scripts/build-iso.sh"]

# Default command (can be overridden)
CMD ["BUILD_VERSION=latest", "ISO_FILENAME=whistlekube-installer.iso"]


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
