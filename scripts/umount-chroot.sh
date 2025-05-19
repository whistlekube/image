#!/bin/bash

set -euxo pipefail

umount /rootfs/dev/pts
umount /rootfs/dev/shm
umount /rootfs/dev
umount /rootfs/proc
umount /rootfs/sys
umount /rootfs/run
