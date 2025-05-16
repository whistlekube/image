
.PHONY: all build clean chroot targetfs livefs docker-buildx-enable shell shell-chroot help

# === Environment ===
# The date of the build
BUILD_DATE := $(shell date -u +%Y%m%d)
# The git branch of the build
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "UNKNOWNBRANCH")
# The git commit hash of the build
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "UNKNOWNCOMMIT")
# The main artifact build target
ARTIFACT_BUILD_TARGET ?= artifact

# === Configuration ===
# The Debian release to base the ISO on
DEBIAN_RELEASE ?= trixie
# The version of the build
BUILD_VERSION ?= dev-${BUILD_DATE}-${GIT_COMMIT}
# The output directory for the build
OUTPUT_DIR ?= $(shell pwd)/output
# The filename of the ISO to build
ISO_FILENAME ?= whistlekube-${DEBIAN_RELEASE}-${BUILD_VERSION}.iso
# The docker target to build
BUILD_TARGET ?= $(ARTIFACT_BUILD_TARGET)
# The name of the Docker image to build
IMAGE_NAME ?= whistlekube-installer-${BUILD_TARGET}
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

# If this is the artifact build target, add the output directory flag
# Otherwise, load the image into the local Docker daemon
ifeq ($(BUILD_TARGET), $(ARTIFACT_BUILD_TARGET))
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

# Build a docker target (default is artifact, which builds the full ISO)
build:
	@echo
	@echo "================================================"
	@echo "Building $(BUILD_TARGET) target..."
	@echo "================================================"
	@echo "Debian release: $(DEBIAN_RELEASE)"
	@echo "Git branch: $(GIT_BRANCH)"
	@echo "Git commit: $(GIT_COMMIT)"
	@echo "Build version: $(BUILD_VERSION)"
	@echo "ISO filename: $(ISO_FILENAME)"
	@echo "Output directory: $(OUTPUT_DIR)"
	@echo "Docker image name: $(IMAGE_NAME)"
	@echo "================================================"
	@echo

	@mkdir -p $(OUTPUT_DIR)
	docker buildx build $(BUILD_FLAGS) -t $(IMAGE_NAME) .
	@echo "ISO has been created at $(OUTPUT_DIR)/$(ISO_FILENAME)"

# Build just the base chroot
chroot:
	@$(MAKE) build BUILD_TARGET=chroot-builder $(MAKEFLAGS)

# Build just the target squashfs filesystem
targetfs:
	@$(MAKE) build BUILD_TARGET=target-builder $(MAKEFLAGS)

# Build the live squashfs filesystem, kernel, and initrd
livefs:
	@$(MAKE) build BUILD_TARGET=live-builder $(MAKEFLAGS)

# Build the ISO (but not the final artifact container)
iso:
	@$(MAKE) build BUILD_TARGET=iso-builder $(MAKEFLAGS)

# Create a new buildx builder with insecure options
docker-buildx-enable:
	@echo "Creating new buildx builder with insecure options..."
	@docker buildx create --use --driver=docker-container --buildkitd-flags "--allow-insecure-entitlement security.insecure"
	@echo "Bootstrapping buildx builder..."
	@docker buildx inspect --bootstrap
	@docker buildx ls

# Clean output and temporary files
clean:
	@echo "Cleaning up..."
	@rm -rf $(OUTPUT_DIR)
	@docker rm -f $(IMAGE_NAME) || true
	@docker rmi -f $(IMAGE_NAME) || true
	@docker system prune -a -f --volumes || true
	@docker buildx prune -f --all || true
	@echo "Clean completed"

# Run an interactive shell in the Docker container
shell: build
	@echo "Running interactive shell in Docker container for target $(BUILD_TARGET)..."
	# Run shell in container
	@docker run --rm -it \
		--privileged \
		-t $(IMAGE_NAME) \
		/bin/bash

shell-chroot:
	@echo "Running interactive shell in chroot-builder container..."
	@$(MAKE) shell BUILD_TARGET=chroot-builder $(MAKEFLAGS)

shell-target:
	@echo "Running interactive shell in target-builder container..."
	@$(MAKE) shell BUILD_TARGET=target-builder $(MAKEFLAGS)

shell-live:
	@echo "Running interactive shell in live-builder container..."
	@$(MAKE) shell BUILD_TARGET=live-builder $(MAKEFLAGS)

shell-iso:
	@echo "Running interactive shell in iso-builder container..."
	@$(MAKE) shell BUILD_TARGET=iso-builder $(MAKEFLAGS)
