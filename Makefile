
.PHONY: all build clean docker-build docker-build-debootstrap docker-buildx-enable shell iso help

# The date of the build
BUILD_DATE := $(shell date +%Y%m%d)
# The git commit hash of the build
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "local")

# Configuration
# The Debian release to base the ISO on
DEBIAN_RELEASE ?= trixie
# The version of the build
BUILD_VERSION ?= dev-${BUILD_DATE}-${GIT_COMMIT}
# The name of the Docker image to build
IMAGE_NAME ?= whistlekube-installer
# The output directory for the build
OUTPUT_DIR ?= $(shell pwd)/build
# The filename of the ISO to build
ISO_FILENAME ?= whistlekube-${DEBIAN_RELEASE}-${BUILD_VERSION}.iso
# The docker target to build
BUILD_TARGET ?= artifact
# Custom build flags to pass to docker buildx
BUILD_FLAGS ?= ""
# Debian mirror to use for the build
DEBIAN_MIRROR ?= http://deb.debian.org/debian

# Default target
all: help

# Help message
help:
	@echo "Whistlekube Installer ISO Builder"
	@echo "-------------------------"
	@echo "Targets:"
	@echo "  build                             - Build the minimal whistlekube installer ISO in Docker"
	@echo "  docker-build BUILD_TARGET=builder - Build the Docker image for the given target"
	@echo "  clean                             - Remove output files and temporary data"
	@echo "  shell                             - Start an interactive shell in the Docker container"
	@echo "  help                              - Show this help message"

# Build the full ISO via Docker
build: docker-build
	@mkdir -p $(OUTPUT_DIR)
	@echo "================================================"
	@echo "Building Installer ISO..."
	@echo "================================================"
	@echo "Debian release: $(DEBIAN_RELEASE)"
	@echo "Git commit: $(GIT_COMMIT)"
	@echo "Build version: $(BUILD_VERSION)"
	@echo "ISO filename: $(ISO_FILENAME)"
	@echo "Output directory: $(OUTPUT_DIR)"
	@echo "Docker image name: $(IMAGE_NAME)"
	@echo "================================================"
	@docker buildx build \
	    --allow security.insecure \
		--target $(BUILD_TARGET) \
		--output type=local,dest=$(OUTPUT_DIR) \
		--progress=plain \
		--build-arg DEBIAN_RELEASE=$(DEBIAN_RELEASE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg DEBIAN_MIRROR=$(DEBIAN_MIRROR) \
		-t $(IMAGE_NAME) \
		.
	@echo "ISO has been created at $(OUTPUT_DIR)/$(ISO_FILENAME)"

# Build Docker image with a configurable target
docker-build:
	@echo "Building Installer target $(BUILD_TARGET)..."

	#@docker buildx build --load \
	#    --allow security.insecure \
	#	--target $(BUILD_TARGET) \
	#	--progress=plain \
	#	-t $(IMAGE_NAME)-$(BUILD_TARGET) \
	#	.

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
shell:
	@echo "Running interactive shell in Docker container for target $(BUILD_TARGET)..."
	# Build the image with --load to ensure the image is available locally
	@make build BUILD_TARGET=$(BUILD_TARGET) BUILD_FLAGS="$(BUILD_FLAGS) --load"
	# Run shell in container
	@docker run --rm -it \
		--privileged \
		-v $(OUTPUT_DIR):/output \
		-t $(IMAGE_NAME)-$(BUILD_TARGET) \
		/bin/bash
