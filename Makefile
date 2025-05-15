
.PHONY: all build clean docker-build docker-build-debootstrap docker-buildx-enable shell iso help

# Configuration
IMAGE_NAME := whistlekube-installer
OUTPUT_DIR := $(shell pwd)/output
ISO_FILENAME := whistlekube-installer.iso
BUILD_VERSION := $(shell date +%Y%m%d)

BUILD_TARGET ?= artifact

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
	@echo "Building Installer ISO..."
	@docker buildx build \
	    --allow security.insecure \
		--output type=local,dest=$(OUTPUT_DIR) \
		--progress=plain \
		-t $(IMAGE_NAME) \
		.
	@echo "ISO has been created at $(OUTPUT_DIR)/$(ISO_FILENAME)"

# Build Docker image with a configurable target
docker-build:
	@echo "Building Installer target $(BUILD_TARGET)..."

	@docker buildx build --load \
	    --allow security.insecure \
		--target $(BUILD_TARGET) \
		--progress=plain \
		-t $(IMAGE_NAME)-$(BUILD_TARGET) \
		.

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
	@docker rmi -f $(IMAGE_NAME)-builder || true
	@docker system prune -a -f --volumes || true
	@docker buildx prune --all || true
	@echo "Clean completed"

# Run an interactive shell in the Docker container
shell: docker-build
	@echo "Running interactive shell in Docker container for target $(BUILD_TARGET)..."
	@mkdir -p $(OUTPUT_DIR)
	# Run shell in container
	@docker run --rm -it \
		--privileged \
		-v $(OUTPUT_DIR):/output \
		-t $(IMAGE_NAME)-$(BUILD_TARGET) \
		/bin/bash
