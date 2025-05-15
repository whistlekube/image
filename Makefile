
.PHONY: all build clean docker-build docker-buildx-enable docker-cleanall shell iso help

# Configuration
IMAGE_NAME := whistlekube-installer-builder
CONTAINER_NAME := whistlekube-installer-builder
OUTPUT_DIR := $(shell pwd)/output
ISO_FILENAME := whistlekube-installer.iso
BUILD_VERSION := $(shell date +%Y%m%d)

# Default target
all: help

# Help message
help:
	@echo "Whistlekube Installer ISO Builder"
	@echo "-------------------------"
	@echo "Targets:"
	@echo "  build        - Build the minimal whistlekube installer ISO in Docker"
	@echo "  docker-build - Build the Docker image only"
	@echo "  clean        - Remove output files and temporary data"
	@echo "  shell        - Start an interactive shell in the Docker container"
	@echo "  help         - Show this help message"

# Build the full ISO via Docker
build: docker-build
	@mkdir -p $(OUTPUT_DIR)
	@echo "Building Debian minimal ISO..."
	# Run docker with verbose output
	@docker run --rm \
		--privileged \
		-v $(OUTPUT_DIR):/output \
		--name $(CONTAINER_NAME) \
		$(IMAGE_NAME) \
		BUILD_VERSION=$(BUILD_VERSION) \
		ISO_FILENAME=$(ISO_FILENAME)
	@echo "ISO has been created at $(OUTPUT_DIR)/$(ISO_FILENAME)"

# Build Docker image
docker-build:
	@echo "Building Docker image..."
	@docker buildx build --allow security.insecure --progress=plain -t $(IMAGE_NAME) -f Dockerfile .

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
	@echo "Clean completed"

docker-cleanall:
	@echo "Cleaning up all Docker images and containers..."
	@docker rm -f $(IMAGE_NAME) || true
	@docker rmi -f $(IMAGE_NAME) || true
	@docker system prune -a -f --volumes || true
	@echo "Clean completed"

# Run an interactive shell in the Docker container
shell: docker-build
	@echo "Running interactive shell in Docker container..."
	@mkdir -p $(OUTPUT_DIR)
	
	# Print docker command
	@echo "docker run --rm -it \
		--privileged \
		-v $(OUTPUT_DIR):/output \
		--name $(CONTAINER_NAME) \
		$(IMAGE_NAME) \
		/bin/sh"
	# Run shell in container
	@docker run --rm -it \
		--privileged \
		-v $(OUTPUT_DIR):/output \
		--name $(CONTAINER_NAME) \
		$(IMAGE_NAME) \
		/bin/sh
