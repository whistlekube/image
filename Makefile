.PHONY: all \
        init \
        build \
        clean \
        chroot \
        qemu-init \
        qemu-iso \
        qemu-iso-bios \
        qemu-iso-uefi \
        qemu-run \
        targetfs \
        livefs \
        iso \
        shell \
        shell-chroot \
        shell-targetfs \
        shell-livefs \
        shell-iso \
        help

# === Environment ===
# The date of the build
BUILD_DATE := $(shell date -u +%Y%m%d)
# The git branch of the build
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "UNKNOWNBRANCH")
# The git commit hash of the build
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "UNKNOWNCOMMIT")
# The main artifact build target
ARTIFACT_BUILD_TARGET := artifact

# === Configuration ===
# The Debian release to base the ISO on
DEBIAN_RELEASE ?= trixie
# The version of the build
BUILD_VERSION ?= $(USER)-${BUILD_DATE}-${GIT_BRANCH}
# The output directory for the build
OUTPUT_DIR ?= $(shell pwd)/output
# The filename of the ISO to build
ISO_FILENAME ?= whistlekube-installer-${BUILD_VERSION}.iso
# The docker target to build
BUILD_TARGET ?= $(ARTIFACT_BUILD_TARGET)
# The name of the Docker image to build
DOCKER_IMAGE_PREFIX ?= whistlekube-installer
DOCKER_IMAGE_NAME ?= ${DOCKER_IMAGE_PREFIX}-${BUILD_TARGET}
DOCKER_BUILDER_NAME ?= ${DOCKER_IMAGE_PREFIX}-builder
# The name of the QEMU image to build
QEMU_IMAGE_PREFIX ?= disk
QEMU_IMAGE_PATH ?= $(OUTPUT_DIR)/${QEMU_IMAGE_PREFIX}.qcow2
# The size of the QEMU image to build
QEMU_IMAGE_SIZE ?= 10G
# The path to the OVMF code file
OVMF_CODE_PATH ?= /usr/share/OVMF/OVMF_CODE_4M.fd
# The path to the OVMF vars file
OVMF_VARS_PATH ?= /usr/share/OVMF/OVMF_VARS_4M.fd
# Custom build flags to pass to docker buildx
EXTRA_BUILD_FLAGS ?=
# Debian mirror to use for the build
DEBIAN_MIRROR ?= http://deb.debian.org/debian

# Build up the complete set of build flags
BUILD_FLAGS := --allow security.insecure \
               --target $(BUILD_TARGET) \
               --progress=plain \
               --build-arg DEBIAN_RELEASE=$(DEBIAN_RELEASE) \
               --build-arg BUILD_VERSION=$(BUILD_VERSION) \
               --build-arg DEBIAN_MIRROR=$(DEBIAN_MIRROR) \
               --build-arg ISO_FILENAME=$(ISO_FILENAME)
# If this is the artifact build target, add the output directory flag
# Otherwise, load the image into the local Docker daemon
ifneq ($(filter %artifact,$(BUILD_TARGET)),)
    BUILD_FLAGS += --output type=local,dest=$(OUTPUT_DIR)
else
    BUILD_FLAGS += --load
endif

BUILD_FLAGS += $(EXTRA_BUILD_FLAGS)

# Default target
all: build

# Help message
help:
	@echo "Whistlekube Installer ISO Builder"
	@echo "-------------------------"
	@echo "Targets:"
	@echo "  build  - Build the minimal whistlekube installer ISO in Docker"
	@echo "  clean  - Remove output files and temporary data"
	@echo "  shell  - Start an interactive shell in the Docker container"
	@echo "  help   - Show this help message"
	@echo ""
	@echo "Options:"
	@echo "  BUILD_TARGET=xxx - Specify build target (default: artifact)"
	@echo "  DEBIAN_RELEASE=xxx - Specify Debian release (default: trixie)"
	@echo "  DEBIAN_MIRROR=xxx - Specify Debian mirror (default: http://deb.debian.org/debian)"
	@echo "  BUILD_VERSION=xxx - Specify build version (default: dev-BUILD_DATE-GIT_COMMIT)"
	@echo "  ISO_FILENAME=xxx - Specify ISO filename (default: whistlekube-installer-BUILD_VERSION.iso)"

# Create a new buildx builder with insecure options
init:
	@echo "Removing existing buildx builder..."
	@docker buildx rm $(DOCKER_BUILDER_NAME) || true
	@echo "Creating new buildx builder with insecure options..."
	@docker buildx create --use --driver=docker-container --buildkitd-flags "--allow-insecure-entitlement security.insecure" --name $(DOCKER_BUILDER_NAME)
	@echo "Bootstrapping buildx builder..."
	@docker buildx inspect --bootstrap
	@docker buildx ls

# Build a docker target (default is artifact, which builds the full ISO)
build:
	@echo
	@echo "================================================"
	@echo "Building $(BUILD_TARGET) target..."
	@echo "================================================"
	@echo "Debian release: $(DEBIAN_RELEASE)"
	@echo "Debian mirror: $(DEBIAN_MIRROR)"
	@echo "Git branch: $(GIT_BRANCH)"
	@echo "Git commit: $(GIT_COMMIT)"
	@echo "Build version: $(BUILD_VERSION)"
	@echo "ISO filename: $(ISO_FILENAME)"
	@echo "Output directory: $(OUTPUT_DIR)"
	@echo "Docker image name: $(DOCKER_IMAGE_NAME)"
	@echo "Extra build flags: $(EXTRA_BUILD_FLAGS)"
	@echo "Build user: $(USER)"
	@echo "Build host: $(shell hostname -f)"
	@echo "Timestamp: $(shell date -u +%Y-%m-%dT%H:%M:%SZ)"
	@echo "================================================"
	@echo

	@mkdir -p $(OUTPUT_DIR)
	docker buildx build $(BUILD_FLAGS) -t $(DOCKER_IMAGE_NAME) .
	@echo "Make build ${BUILD_TARGET} completed successfully"

# Build just the base chroot
chroot:
	@$(MAKE) build BUILD_TARGET=chroot-builder $(MAKEFLAGS)

# Build just the target squashfs filesystem
targetfs:
	@$(MAKE) build BUILD_TARGET=targetfs-build $(MAKEFLAGS)

# Build the live squashfs filesystem, kernel, and initrd
livefs:
	@$(MAKE) build BUILD_TARGET=livefs-build $(MAKEFLAGS)

# Build the ISO (but not the final artifact container)
iso:
	@$(MAKE) build BUILD_TARGET=iso-build $(MAKEFLAGS)

# Clean output and temporary files
clean:
	@echo "Cleaning up..."
	@rm -rf $(OUTPUT_DIR)
	@docker rm -f $(DOCKER_IMAGE_PREFIX)* || true
	@docker rmi -f $(DOCKER_IMAGE_NAME) || true
	@docker system prune -a -f --volumes || true
	@docker buildx prune -f --all || true
	@echo "Clean completed"

# Run an interactive shell in the Docker container
shell: build
	@echo "Running interactive shell in Docker container for target $(BUILD_TARGET)..."
	# Run shell in container
	@docker run --rm -it \
		--privileged \
		-t $(DOCKER_IMAGE_NAME) \
		/bin/bash

shell-chroot:
	@echo "Running interactive shell in chroot-builder container..."
	@$(MAKE) shell BUILD_TARGET=chroot-builder $(MAKEFLAGS)

shell-targetfs:
	@echo "Running interactive shell in targetfs-build container..."
	@$(MAKE) shell BUILD_TARGET=targetfs-build $(MAKEFLAGS)

shell-livefs:
	@echo "Running interactive shell in livefs-build container..."
	@$(MAKE) shell BUILD_TARGET=livefs-build $(MAKEFLAGS)

shell-iso:
	@echo "Running interactive shell in iso-build container..."
	@$(MAKE) shell BUILD_TARGET=iso-build $(MAKEFLAGS)

# Build a QEMU image
qemu-init:
	@echo "Building QEMU image..."
	qemu-img create -f qcow2 $(QEMU_IMAGE_PATH) $(QEMU_IMAGE_SIZE)
	cp $(OVMF_VARS_PATH) $(OUTPUT_DIR)/OVMF_VARS.fd

# Partitions the disk and runs the whistlekube installer
qemu-install:
	@$(MAKE) build DOCKER_IMAGE_NAME=whistlekube-qemu-installer BUILD_TARGET=qemu-installer $(MAKEFLAGS)
	docker run --rm --privileged \
		--cap-add=SYS_ADMIN --device /dev/nbd0 \
		-v /dev:/dev \
		-v $(OUTPUT_DIR):/output \
		whistlekube-qemu-installer

# Run a QEMU instance booting from the installer ISO (BIOS)
qemu-iso-bios:
	qemu-system-x86_64 -m 1G -drive file=$(QEMU_IMAGE_PATH),format=qcow2,if=virtio -cdrom $(OUTPUT_DIR)/$(ISO_FILENAME) -boot d

# Run a QEMU instance booting from the installer ISO (UEFI)
qemu-iso: qemu-iso-uefi
qemu-iso-uefi:
	qemu-system-x86_64 -m 1G -drive file=$(QEMU_IMAGE_PATH),format=qcow2,if=virtio \
		-cdrom $(OUTPUT_DIR)/$(ISO_FILENAME) \
		-boot d \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE_PATH) \
		-drive if=pflash,format=raw,file=$(OUTPUT_DIR)/OVMF_VARS.fd

# Run a QEMU instance on the target filesystem
qemu-run-bios:
	qemu-system-x86_64 -m 1G -drive file=$(QEMU_IMAGE_PATH),format=qcow2,if=virtio -boot c

# Run a QEMU instance on the target filesystem
qemu-run: qemu-run-uefi
qemu-run-uefi:
	qemu-system-x86_64 -m 1G -drive file=$(QEMU_IMAGE_PATH),format=qcow2,if=virtio \
		-boot c \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE_PATH) \
		-drive if=pflash,format=raw,file=$(OUTPUT_DIR)/OVMF_VARS.fd
