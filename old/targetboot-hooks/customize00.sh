#!/bin/sh

set -eux

rootdir="$1"

#KERNEL_REAL_VER=$(dpkg-query -W -f='${Provides}' ${KERNEL_PACKAGE} | grep -o 'linux-image-[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+-[a-z0-9]\+' | sed 's/linux-image-//' | sort -V | tail -n 1)
#KVER=$(ls -1 $rootdir/lib/modules | sort -V | tail -n1)

# Build initrd with dracut
cp /dracut.conf "$rootdir/etc/dracut.conf.d/99-whistlekube.conf"
chroot "$rootdir" dracut \
    --no-hostonly \
    --kver ${KVER} \
    --kmoddir /lib/modules/${KVER} \
    --omit-drivers "network sound media wireless pcmcia scsi usb firewire ieee1394 ata_piix mptspi nvme nbd virtio_blk virtio_scsi virtio_net" \
    --add-drivers "loop squashfs overlay" \
    /initrd-whistlekube.img

    --conf /etc/dracut.conf.d/99-whistlekube.conf \

# Install busybox to the target rootfs
#chroot "$rootdir" /bin/busybox --install -s
