#!/bin/bash

mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    busybox-static

umount /proc
umount /sys
umount /dev/pts
