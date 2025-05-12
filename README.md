# image
Installer iso image for whistlekube. Based on Debian using debootstrap

## Project Structure

```
firewall-iso-builder/
├── Makefile              # Main build orchestration
├── config/               # Build configuration variables
│   ├── config.mk         # Main config variables (release, arch, kernel, mirror, etc.)
│   └── packages.list     # Packages to install with debootstrap
├── target-rootfs/        # Source files for the system *to be installed*
│   ├── files/            # Files to copy into the debootstrap chroot *before* customization script
│   │   ├── usr/local/bin/your-firewall-agent
│   │   ├── etc/firewall/config/initial-config.yaml
│   │   └── etc/systemd/system/your-firewall-agent.service
│   └── chroot-script.sh  # Script to run inside the debootstrap chroot
├── installer-initramfs/  # Source files and structure for the installer initramfs
│   ├── overlay/          # Files and directories to include in the initramfs root
│   │   ├── bin/          # BusyBox symlinks will go here
│   │   ├── sbin/         # BusyBox symlinks will go here
│   │   ├── etc/          # Minimal /etc files (optional)
│   │   ├── lib/          # Libraries needed by initramfs binaries
│   │   ├── lib64/        # Libraries needed by initramfs binaries
│   │   └── modules/      # Kernel modules for initramfs (storage, network)
│   ├── init              # The first script run by the kernel
│   └── installer-script.sh # The script that handles partitioning and copying
├── iso-boot/             # Files that go directly into the ISO's bootable part
│   ├── grub/
│   │   └── grub.cfg      # GRUB config for the ISO menu
│   └── EFI/
│       └── BOOT/         # UEFI boot files
│           └── grub.cfg  # EFI specific grub config (can chainload main one)
├── scripts/              # Helper scripts used during the build
│   ├── copy_libs.sh      # Analyze binaries and copy their libraries
│   └── copy_modules.sh   # Copy specified kernel modules
└── output/               # Build artifacts (the final ISO goes here)
```