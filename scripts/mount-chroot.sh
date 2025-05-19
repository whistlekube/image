#!/bin/bash

set -euxo pipefail

mount --bind /dev /rootfs/dev
mount --bind /proc /rootfs/proc
mount --bind /sys /rootfs/sys
mount --bind /run /rootfs/run
mount --bind /dev/pts /rootfs/dev/pts
mount --bind /dev/shm /rootfs/dev/shm
