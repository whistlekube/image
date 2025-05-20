#!/bin/bash

# Source the functions
source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

# Mount filesystems
mount_filesystems

export DEBIAN_FRONTEND=noninteractive

# Install busybox
apt-get update

# Purge unnecessary packages
apt-get purge --allow-remove-essential --auto-remove -y \
  bsdutils  \
  debian-archive-keyring  \
  debianutils  \
  debootstrap  \
  diffutils  \
  distro-info  \
  distro-info-data  \
  findutils  \
  gcc-14-base  \
  grep  \
  gzip  \
  hostname  \
  perl-base
