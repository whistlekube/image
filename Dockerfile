# Use a Debian trixie base image
FROM debian:trixie-slim

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive

# Labels following OCI image spec
LABEL org.opencontainers.image.title="Whistlekube Installer ISO Builder"
LABEL org.opencontainers.image.description="A Docker image to build whistlekube installer ISOs"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.authors="Joe Kramer <joe@whistlekube.com>"

# Install required packages in a single RUN instruction to reduce layers
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        debootstrap \
        xorriso \
        isolinux \
        syslinux-common \
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
        systemd-container \
        xz-utils \
        file \
        bzip2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create directories for scripts, config, and output
WORKDIR /build
RUN mkdir -p /scripts /config /output

# Copy scripts and configuration files
COPY scripts/ /scripts/
COPY config/ /config/

# Make scripts executable
RUN chmod +x /scripts/*.sh

# Set entrypoint to the build script
ENTRYPOINT ["/scripts/build-iso.sh"]

# Default command (can be overridden)
CMD ["BUILD_VERSION=latest", "ISO_FILENAME=whistlekube-installer.iso"]
