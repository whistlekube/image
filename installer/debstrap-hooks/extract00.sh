#!/bin/bash

set -eux

rootfs="$1"

if [ -z "$rootfs" ]; then
    echo "Error: rootfs is not set" >&2
    exit 1
fi


