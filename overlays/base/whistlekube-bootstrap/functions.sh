#!/bin/bash

set -euxo pipefail

function mount_filesystems() {
    mount none -t proc /proc
    mount none -t sysfs /sys
    mount none -t devpts /dev/pts
}

function unmount_filesystems() {
    umount /proc
    umount /sys
    umount /dev/pts
}

function cleanup_apt() {
    # Remove unnecessary packages
    echo "Removing unnecessary packages..."
    apt-get remove -y --purge installation-report tasksel tasksel-data || true
    apt-get autoremove -y --purge || true
    apt-get clean || true

    # Clean apt caches to reduce image size
    echo "Cleaning apt caches..."
    rm -rf /var/lib/apt/lists/*
}

function cleanup_boot() {
    rm -rf /{boot,initrd.img*,vmlinuz*}
}
