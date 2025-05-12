# Load configuration variables
include config/config.mk

DOCKER_IMAGE_NAME ?= wistlekube-installer-builder
DOCKERFILE ?= Dockerfile
HOST_OUTPUT_DIR ?= ./output
PRIVILEGED_BUILDER_NAME ?= wistlekube-privileged-iso-builder

.PHONY: all clean distclean target-rootfs-built installer-initramfs iso docker-build docker-builder-create docker-builder-remove

all: docker-build

# --- Docker Build Target ---
# This target invokes the multi-stage docker build which runs the 'iso' target internally
docker-build: docker-builder-create $(DOCKERFILE) $(shell find config installer-initramfs iso-boot target-rootfs -type f) # Depend on source files
	@echo "--> Building ISO via Docker multi-stage build..."
	# Create the host output directory if it doesn't exist
	mkdir -p $(HOST_OUTPUT_DIR)
	# Use docker buildx build with --output to extract the artifact
	# --load is useful if you want to inspect the final scratch image (not strictly necessary)
	# --platform is good practice even for native arch
	docker buildx build \
		--builder $(PRIVILEGED_BUILDER_NAME) \
		--platform linux/$(ARCH) \
		--load \
		--progress=plain \
		--output type=local,dest="$(HOST_OUTPUT_DIR)" \
		--build-arg DEBIAN_RELEASE=$(DEBIAN_RELEASE) \
		--build-arg ARCH=$(ARCH) \
		-t $(DOCKER_IMAGE_NAME) \
		-f $(DOCKERFILE) .

docker-builder-create:
	@if ! docker buildx ls | grep -q "^$(PRIVILEGED_BUILDER_NAME) "; then \
		echo "--> Creating privileged buildx builder: $(PRIVILEGED_BUILDER_NAME)"; \
		docker buildx create --name $(PRIVILEGED_BUILDER_NAME) --driver docker-container; \
	else \
		echo "--> Buildx builder $(PRIVILEGED_BUILDER_NAME) already exists."; \
	fi

docker-builder-remove:
	@if docker buildx ls | grep -q "^$(PRIVILEGED_BUILDER_NAME) "; then \
		echo "--> Removing buildx builder: $(PRIVILEGED_BUILDER_NAME)"; \
		docker buildx rm $(PRIVILEGED_BUILDER_NAME); \
	else \
		echo "--> Buildx builder $(PRIVILEGED_BUILDER_NAME) does not exist."; \
	fi

# --- Main ISO Build Target ---
iso: $(ISO_FILE)

$(ISO_FILE): $(ISO_ROOT)
	@echo "--> Building ISO image '$@'"
	# Ensure EFI directory exists if it wasn't created by iso-content
	mkdir -p $(ISO_ROOT)/EFI/BOOT

	# Hybrid ISO build for BIOS and UEFI
	# Uses grub-mkrescue as it handles many complexities of getting a bootable GRUB ISO
	grub-mkrescue -o "$@" \
		--mod-dir=/usr/lib/grub/i386-pc \
		--mod-dir=/usr/lib/grub/x86_64-efi \
		--xorriso="/usr/bin/xorriso" \
		--locales="" --fonts="" \
		--grub-mkimage="$(shell which grub-mkimage)" \
		--overlay="$(ISO_ROOT)" \
		/usr/lib/grub/i386-pc/ \
		/usr/lib/grub/x86_64-efi/

	# The grub-mkrescue approach is simpler but sometimes less flexible than raw xorriso
	# If you need more control, use the raw xorriso command from the previous answer,
	# ensuring you have the correct bootloader images (eltorito.img, grubx64.efi, isohdpfx.bin)

$(ISO_ROOT): iso-content
	@echo "--> ISO root prepared at '$@'"

iso-content: target-squashfs installer-initrd $(ISO_BOOT_SRC)
	@echo "--> Preparing ISO content root '$@'"
	rm -rf $(ISO_ROOT) # Clean previous content
	mkdir -p $(ISO_ROOT)/boot/grub
	mkdir -p $(ISO_ROOT)/install
	mkdir -p $(ISO_ROOT)/EFI/BOOT

	# Copy kernel
	cp /boot/vmlinuz-$(KERNEL_VERSION) $(ISO_ROOT)/boot/vmlinuz

	# Copy generated initrd (from installer-initramfs target)
	cp $(INITRAMFS_DIR)/initrd.gz $(ISO_ROOT)/boot/

	# Copy generated squashfs (from target-squashfs target)
	cp $(SQUASHFS_FILE) $(ISO_ROOT)/install/

	# Copy bootloader configs and files from source
	cp $(ISO_BOOT_SRC)/grub/grub.cfg $(ISO_ROOT)/boot/grub/
	cp $(ISO_BOOT_SRC)/EFI/BOOT/grub.cfg $(ISO_ROOT)/EFI/BOOT/ # For UEFI

	# Copy GRUB EFI executable (needed by grub-mkrescue or xorriso)
	# grub-mkrescue usually handles this if you include the /usr/lib/grub paths
	# But explicit copy is safer if you're not using the --overlay option extensively
	# cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi $(ISO_ROOT)/EFI/BOOT/BOOTX64.EFI || true # Handles signed/unsigned


# --- Target Root Filesystem Build ---
target-squashfs: $(TARGET_DIR)
	@echo "--> Creating SquashFS from target rootfs '$<'"
	# Using xz for better compression, can change to gzip or leave blank
	mkdir -p $(SQUASHFS_DIR)
	mksquashfs $(TARGET_DIR) $(SQUASHFS_FILE) -comp xz -no-xattrs -no-dev -no-sparse

$(TARGET_DIR): target-rootfs-built
	@echo "--> Target rootfs built at '$@'"

target-rootfs-built: $(CONFIG_DIR)/config.mk $(CONFIG_DIR)/packages.list $(TARGET_ROOTFS_SRC)
	@echo "--> Running debootstrap and chroot customization..."
	# Clean previous build
	rm -rf $(TARGET_DIR)
	mkdir -p $(TARGET_DIR)

	# 1. Run debootstrap
	@echo "  - Running debootstrap..."
	debootstrap --variant=minbase --arch $(ARCH) $(DEBIAN_RELEASE) $(TARGET_DIR) $(DEBIAN_MIRROR)

	# Check if debootstrap succeeded
	@if [ ! -f "$(TARGET_DIR)/etc/debian_version" ]; then \
		echo "Error: Debootstrap failed!"; exit 1; \
	fi

	# 2. Copy files into the chroot *before* running the script
	@echo "  - Copying files to target rootfs..."
	cp -a $(TARGET_ROOTFS_SRC)/files/. $(TARGET_DIR)/ || true # Use || true to handle empty files dir

	# 3. Copy the chroot script
	cp $(TARGET_ROOTFS_SRC)/chroot-script.sh $(TARGET_DIR)/tmp/chroot-script.sh

	# 4. Chroot and run the customization script
	@echo "  - Running chroot script..."
	mount -t proc /proc $(TARGET_DIR)/proc
	mount -t sysfs /sys $(TARGET_DIR)/sys
	mount -o bind /dev $(TARGET_DIR)/dev
	mount -o bind /dev/pts $(TARGET_DIR)/dev/pts
	chroot $(TARGET_DIR) /bin/bash /tmp/chroot-script.sh
	# Check chroot script exit status
	@if [ $$? -ne 0 ]; then \
		echo "Error: Chroot script failed!"; \
		umount $(TARGET_DIR)/dev/pts || true; \
		umount $(TARGET_DIR)/dev || true; \
		umount $(TARGET_DIR)/sys || true; \
		umount $(TARGET_DIR)/proc || true; \
		exit 1; \
	fi
	rm $(TARGET_DIR)/tmp/chroot-script.sh # Clean up the script

	# 5. Unmount filesystems
	@echo "  - Unmounting chroot filesystems..."
	umount $(TARGET_DIR)/dev/pts || true # Use || true if already unmounted
	umount $(TARGET_DIR)/dev || true
	umount $(TARGET_DIR)/sys || true
	umount $(TARGET_DIR)/proc || true
	sync # Ensure writes are flushed

# --- Installer Initramfs Build ---
installer-initramfs: $(INITRAMFS_DIR)/initrd.gz

$(INITRAMFS_DIR)/initrd.gz: $(INSTALLER_INITRAMFS_SRC) $(CONFIG_DIR)/config.mk
	@echo "--> Building installer initramfs..."
	rm -rf $(INITRAMFS_DIR) # Clean previous build
	mkdir -p $(INITRAMFS_DIR)/overlay/

	# 1. Copy initramfs files (init, installer script)
	cp $(INSTALLER_INITRAMFS_SRC)/init $(INITRAMFS_DIR)/overlay/
	cp $(INSTALLER_INITRAMFS_SRC)/installer-script.sh $(INITRAMFS_DIR)/overlay/

	# 2. Copy BusyBox binary
	cp $(shell which busybox) $(INITRAMFS_DIR)/overlay/bin/
	# Create symlinks for busybox commands (run this inside the overlay dir)
	cd $(INITRAMFS_DIR)/overlay/bin && busybox --install -s . && cd -

	# 3. Configure mkinitramfs
	# Copy or create mkinitramfs hooks/configs in the overlay if needed
	# For a basic initramfs, mkinitramfs built-ins are often enough.
	# To include specific modules/binaries, you can use /etc/mkinitramfs/modules,
	# hooks, or conf.d snippets copied into the overlay structure.
	# Example: Add a file listing modules to always include
	echo "$(INITRAMFS_MODULES)" | tr ' ' '\n' > $(INITRAMFS_DIR)/overlay/etc/mkinitramfs/modules # mkinitramfs reads this

	# Also copy tools needed by the installer-script.sh if they aren't in busybox
	# Example: parted, sfdisk, mkfs.ext4 need to be available in the initramfs
	# mkinitramfs tries to include dependencies, but explicit copy or hooks might be needed
	# This is where mkinitramfs customization gets complex.
	# For now, rely on mkinitramfs defaults + /etc/mkinitramfs/modules

	# 4. Generate the initramfs using mkinitramfs
	@echo "  - Running mkinitramfs..."
	# mkinitramfs takes an overlay directory (-o) and kernel version
	# --base-dir is where it looks for the kernel modules and libs
	mkinitramfs \
		-o $(INITRAMFS_DIR)/initrd.gz \
		-k $(KERNEL_VERSION) \
		--base-dir / \
		--overlay $(INITRAMFS_DIR)/overlay/

	# mkinitramfs relies on kernel and modules *being present in the build environment*
	# The Dockerfile ensures linux-image-amd64 and linux-headers-amd64 are installed.

# --- Cleanup Targets ---
# This clean target runs on the HOST to remove artifacts created by docker-build
docker-clean:
	@echo "--> Cleaning host build artifacts..."
	rm -rf $(HOST_OUTPUT_DIR)
	# You might also want to remove the intermediate docker image if you don't use --load
	docker rmi $(DOCKER_IMAGE_NAME) || true
	
# This clean target is for manual runs *inside* the container if needed for debugging
# It's NOT run by the main 'docker-build' process typically
clean:
	@echo "--> Cleaning build artifacts..."
	sudo rm -rf $(OUTPUT_DIR) $(TARGET_DIR) $(INITRAMFS_DIR) $(ISO_ROOT) $(SQUASHFS_FILE)

distclean: clean docker-builder-remove
	@echo "--> Cleaning debootstrap cache (optional, can be large)..."
	# Debootstrap cache location varies, check debootstrap man page or common paths
	# For default behavior on many systems, it's in /var/cache/debootstrap
	# sudo rm -rf /var/cache/debootstrap/$(DEBIAN_RELEASE)
