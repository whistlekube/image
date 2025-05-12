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
COPY . .

FROM builder as builder-rootfs-stage
ARG DEBIAN_RELEASE=trixie
ARG ARCH=amd64

# 1. Run debootstrap
# Use buildd variant for minimal system
RUN debootstrap --variant=minbase --arch $(ARCH) $(DEBIAN_RELEASE) /target-rootfs http://deb.debian.org/debian/

# Check if debootstrap succeeded (optional but good for debugging build process)
RUN test -f "/target-rootfs/etc/debian_version" || (echo "Error: Debootstrap failed!"; exit 1;)

# Squash the root filesystem
FROM builder AS squashfs-stage
COPY --from=builder-rootfs-stage /target-rootfs /target-rootfs
# Using xz for better compression, can change to gzip or leave blank
RUN mksquashfs /target-rootfs /rootfs.squashfs -comp xz -no-xattrs -no-dev -no-sparse
# Export the squashed filesystem
VOLUME /rootfs.squashfs
CMD ["/rootfs.squashfs"] # Not executed, just a hint

# --- Stage 3: Build Installer Initramfs ---
FROM builder AS initramfs-stage
ARG KERNEL_VERSION
ARG INITRAMFS_MODULES # Pass as build arg

WORKDIR /build

# Copy initramfs sources
COPY installer-initramfs/init installer-initramfs/installer-script.sh installer-initramfs/mkinitramfs-config/ /build/installer-initramfs/

# Create overlay directory and copy base files
RUN mkdir -p /initramfs-overlay/bin \
    /initramfs-overlay/lib/modules/$(KERNEL_VERSION) \
    /initramfs-overlay/etc/mkinitramfs/ \
    /initramfs-overlay/usr/lib/grub/i386-pc /initramfs-overlay/usr/lib/grub/x86_64-efi # Needed for grub-mkrescue --overlay

# Copy init and installer script to overlay
RUN cp /build/installer-initramfs/init /initramfs-overlay/init \
    && cp /build/installer-initramfs/installer-script.sh /initramfs-overlay/installer-script.sh

# Copy busybox and install symlinks in overlay
RUN cp $(which busybox) /initramfs-overlay/bin/ \
    && cd /initramfs-overlay/bin \
    && busybox --install -s . \
    && cd /build

# Configure mkinitramfs modules list in overlay
RUN echo "$(INITRAMFS_MODULES)" | tr ' ' '\n' > /initramfs-overlay/etc/mkinitramfs/modules

# Copy grub modules needed by grub-mkrescue overlay? Maybe not needed if --mod-dir used.
# cp /usr/lib/grub/i386-pc/* /initramfs-overlay/usr/lib/grub/i386-pc/ || true
# cp /usr/lib/grub/x86_64-efi/* /initramfs-overlay/usr/lib/grub/x86_64-efi/ || true


# Generate the initramfs using mkinitramfs
RUN mkinitramfs \
    -o /initrd.gz \
    -k $(KERNEL_VERSION) \
    --base-dir / \
    --overlay /initramfs-overlay/

# Export the initrd
VOLUME /initrd.gz
CMD ["/initrd.gz"] # Not executed

# --- Stage 4: Package the ISO ---
FROM builder AS iso-stage
ARG ISO_LABEL

WORKDIR /iso-root

# Copy kernel (from the kernel package installed in the builder stage)
RUN cp /boot/vmlinuz-$(ARCH) /iso-root/boot/vmlinuz

# Copy generated initrd from initramfs-stage
COPY --from=initramfs-stage /initrd.gz /iso-root/boot/

# Copy generated squashfs from squashfs-stage
COPY --from=squashfs-stage /rootfs.squashfs /iso-root/install/rootfs.squashfs

# Copy bootloader configs and files from source
COPY iso-boot/grub/grub.cfg /iso-root/boot/grub/
COPY iso-boot/EFI/BOOT/grub.cfg /iso-root/EFI/BOOT/
# Copy GRUB EFI executable - needed by grub-mkrescue or explicit xorriso
RUN mkdir -p /iso-root/EFI/BOOT
RUN cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi /iso-root/EFI/BOOT/BOOTX64.EFI || true

# Build the ISO using grub-mkrescue (as it's easier)
RUN grub-mkrescue -o /final-iso.iso \
    --mod-dir=/usr/lib/grub/i386-pc \
    --mod-dir=/usr/lib/grub/x86_64-efi \
    --xorriso="$(which xorriso)" \
    --locales="" --fonts="" \
    --grub-mkimage="$(which grub-mkimage)" \
    --overlay=/iso-root # Point overlay to our prepared directory

# Final output: the ISO file
VOLUME /final-iso.iso
CMD ["/final-iso.iso"] # Not executed, just for buildx output
