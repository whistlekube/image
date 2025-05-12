# Use a Debian base image matching your target release or a recent stable one
FROM debian:trixie as builder

ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages for the build environment
# debootstrap: To create the root filesystem
# qemu-user-static: Needed by debootstrap for non-native architectures (good practice even for native)
# squashfs-tools: To compress the root filesystem
# xorriso: To create the ISO image
# grub-pc-bin, grub-efi-amd64-bin: GRUB binaries
# mtools, dosfstools: Needed by GRUB tools for FAT filesystems (EFI partition)
# syslinux-utils: For hybrid ISO MBR image (isohdpfx.bin)
# busybox: Provides essential utilities for the installer initramfs
# linux-image-amd64, linux-headers-amd64: Kernel and headers needed by mkinitramfs
# mkinitramfs: The tool to generate the initramfs
# parted, sfdisk, e2fsprogs: Disk partitioning and formatting tools needed in initramfs
# cpio, gzip: Used by mkinitramfs packaging
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    debootstrap \
    qemu-user-static \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    make \
    dosfstools \
    syslinux-utils \
    busybox \
    linux-image-amd64 \
    linux-headers-amd64 \
    initramfs-tools \
    parted \
    util-linux \
    e2fsprogs \
    cpio gzip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy the entire project source into the container
COPY . /build/

# --- Execute the build process INSIDE this stage ---
# This runs the 'all' target (which defaults to 'iso') in the Makefile
# This target generates the ISO file at /build/output/<iso_filename>
RUN make iso

# --- Stage 2: Extract the Artifact ---
# Use a minimal base image to just hold the artifact
FROM scratch

# Use build arguments to construct the ISO filename dynamically
ARG DEBIAN_RELEASE=trixie
ARG ARCH=amd64
ENV ISO_FILENAME=wistlekube-installer-${DEBIAN_RELEASE}-${ARCH}.iso

# Copy the generated ISO file from the 'builder' stage to the root of this final image
# The path /build/output/${ISO_FILENAME} must match where your Makefile puts the ISO
COPY --from=builder /build/output/${ISO_FILENAME} /

# Metadata (optional)
LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="Debian Custom Install ISO"
LABEL com.example.build.timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

# This final image is not meant to be run, only to be extracted using --output
