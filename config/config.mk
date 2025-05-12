# --- Build Configuration ---
DEBIAN_RELEASE = trixie
ARCH = amd64
DEBIAN_MIRROR = http://deb.debian.org/debian/

# Kernel version to use (needs matching linux-image and linux-headers packages installed on BUILD system)
# You might need to check `ls /lib/modules` after installing headers
KERNEL_VERSION = $(shell ls /lib/modules | head -n 1) # Example: assumes only one kernel installed
# Alternatively, hardcode: KERNEL_VERSION = 6.1.0-13-amd64

# --- Paths ---
SRC_DIR = $(shell pwd)
OUTPUT_DIR = $(SRC_DIR)/output
BUILD_DIR = $(SRC_DIR)/build
TARGET_DIR = $(BUILD_DIR)/target-rootfs-build
INITRAMFS_DIR = $(BUILD_DIR)/installer-initramfs-build
ISO_ROOT = $(BUILD_DIR)/iso-root

# Source directories (relative to Makefile)
CONFIG_DIR = $(SRC_DIR)/config
TARGET_ROOTFS_SRC = $(SRC_DIR)/target-rootfs
INSTALLER_INITRAMFS_SRC = $(SRC_DIR)/installer-initramfs
ISO_BOOT_SRC = $(SRC_DIR)/iso-boot
SCRIPTS_DIR = $(SRC_DIR)/scripts

# Output file names
SQUASHFS_DIR = $(ISO_ROOT)/install
SQUASHFS_FILE = $(SQUASHFS_DIR)/rootfs.squashfs
INITRD_FILE = $(ISO_ROOT)/boot/initrd.gz
ISO_FILE = $(OUTPUT_DIR)/wistlekube-installer-$(DEBIAN_RELEASE)-$(ARCH).iso
ISO_LABEL = WISTLEKUBE_INSTALL

# --- Installer Initramfs Configuration ---
# Binaries to include in the installer initramfs (needed by init or installer-script.sh)
INITRAMFS_BINARIES = busybox grub-install grub-mkconfig mkfs.ext4 parted mount umount chroot sleep sync modprobe cp rm mv mkdir rmdir cat echo dd unsquashfs

# Kernel modules to include in the initramfs (storage drivers, network drivers, filesystem modules)
INITRAMFS_MODULES = virtio_blk sd_mod ata_piix ahci libahci virtio_net e1000e igb r8169 xfs ext4 isofs # Add drivers for your target hardware!

# --- Debootstrap Configuration ---
PACKAGES_LIST = $(CONFIG_DIR)/packages.list
#DEBOOTSTRAP_INCLUDE = #--include=systemd
# Add daemon dependencies to DEBOOTSTRAP_INCLUDE or PACKAGE_LIST
# DEBOOTSTRAP_INCLUDE += ,libnl-3-200,libnl-route-3-200,libyaml-cpp0.7 # Example

# --- Bootloader Configuration ---
GRUB_PC_MODULES = normal configfile linux part_msdos part_gpt ext2 fat iso9660 biosdisk
GRUB_EFI_MODULES = normal configfile linux part_msdos part_gpt ext2 fat iso9660 part_efi chain
GRUB_COMMON_MODULES = $(GRUB_PC_MODULES) $(GRUB_EFI_MODULES)
