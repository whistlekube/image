#!/bin/bash
# This is the main installer script that runs in the live environment

echo "************************************************************"
echo "Whistlekube Installer"
echo "************************************************************"

dialog --msgbox "Welcome to the Whistlekube Installer!\n\nThis is where your installation logic would go.\n\n- Partitioning\n- Formatting\n- Copying target.squashfs\n- Installing GRUB to target" 15 60

# Define paths
CDROM_MOUNT="/cdrom"  # live-boot typically mounts the installation media here
TARGET_SQUASHFS="${CDROM_MOUNT}/live/target.squashfs"
TARGET_MOUNT="/target"

# Function to set up dialog UI
setup_ui() {
  # Configure dialog settings
  export DIALOGRC="/etc/dialogrc"
  export DIALOG_BACKTITLE="Whistlekube Installer"
}

# Function to partition disk
partition_disk() {
  local disk="$1"
  
  # Show partitioning dialog
  dialog --title "Partitioning" --yesno "This will erase all data on $disk. Continue?" 8 60
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Create partitions
  parted -s "$disk" mklabel gpt
  parted -s "$disk" mkpart primary fat32 1MiB 513MiB
  parted -s "$disk" set 1 esp on
  parted -s "$disk" mkpart primary ext4 513MiB 100%
  
  # Format partitions
  mkfs.vfat "${disk}1"
  mkfs.ext4 "${disk}2"
  
  return 0
}

# Function to mount target filesystem
mount_target() {
  local disk="$1"
  
  # Create mount point
  mkdir -p "$TARGET_MOUNT"
  
  # Mount root partition
  mount "${disk}2" "$TARGET_MOUNT"
  
  # Create and mount boot/efi
  mkdir -p "$TARGET_MOUNT/boot/efi"
  mount "${disk}1" "$TARGET_MOUNT/boot/efi"
}

# Function to install system
install_system() {
  dialog --title "Installing" --infobox "Installing system files..." 5 70
  
  # Mount squashfs if not already mounted
  if [ ! -d "/mnt/squashfs" ]; then
    mkdir -p /mnt/squashfs
    mount -t squashfs -o ro "$TARGET_SQUASHFS" /mnt/squashfs
  fi
  
  # Copy files (use rsync for better progress reporting)
  rsync -a /mnt/squashfs/ "$TARGET_MOUNT/"
  
  # Clean up
  umount /mnt/squashfs
}

# Function to install bootloader
install_bootloader() {
  local disk="$1"
  
  # Chroot and install GRUB
  for dir in /dev /proc /sys; do
    mount --bind $dir "$TARGET_MOUNT$dir"
  done
  
  chroot "$TARGET_MOUNT" grub-install "$disk"
  chroot "$TARGET_MOUNT" update-grub
  
  # Unmount
  for dir in /sys /proc /dev; do
    umount "$TARGET_MOUNT$dir"
  done
}

# Function to configure system
configure_system() {
  # Set hostname
  echo "firewall" > "$TARGET_MOUNT/etc/hostname"
  
  # Configure network (example)
  cat > "$TARGET_MOUNT/etc/network/interfaces.d/eth0" << EOF
auto eth0
iface eth0 inet dhcp
EOF
  
  # Additional configuration as needed
}

# Main installation workflow
main() {
  setup_ui
  
  # Select disk to install to
  disk=$(dialog --stdout --title "Disk Selection" --menu "Select disk to install to:" 15 60 5 \
    $(lsblk -d -o NAME,SIZE -n -e 7,11 | awk '{print "/dev/"$1 " " $2}'))
  
  if [ -z "$disk" ]; then
    dialog --title "Cancelled" --msgbox "Installation cancelled." 5 40
    exit 1
  fi
  
  # Perform installation steps
  if ! partition_disk "$disk"; then
    dialog --title "Cancelled" --msgbox "Installation cancelled." 5 40
    exit 1
  fi
  
  mount_target "$disk"
  install_system
  install_bootloader "$disk"
  configure_system
  
  # Unmount target
  umount -R "$TARGET_MOUNT"
  
  # Installation complete
  dialog --title "Installation Complete" --msgbox "Firewall system has been installed. The system will now reboot." 7 60
  
  # Reboot
  reboot
}

# Start installation
main

