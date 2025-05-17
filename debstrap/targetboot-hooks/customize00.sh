#!/bin/sh

set -eux

rootdir="$1"

#KERNEL_REAL_VER=$(dpkg-query -W -f='${Provides}' ${KERNEL_PACKAGE} | grep -o 'linux-image-[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+-[a-z0-9]\+' | sed 's/linux-image-//' | sort -V | tail -n 1)
KVER=$(ls -1 $rootdir/lib/modules | sort -V | tail -n1)

# Build initrd with dracut
#chroot "$rootdir" dracut --no-hostonly /whistlekube-initrd.img ${KVER}

# Install busybox to the target rootfs
#chroot "$rootdir" /bin/busybox --install -s
