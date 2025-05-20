#!/bin/bash

if [[ "${_WHISTLEKUBE_PARTITION_INCLUDED:-}" != "yes" ]]; then
_WHISTLEKUBE_PARTITION_INCLUDED=yes

partition_device() {
    local disk="$1"
    local part_num="$2"

    # Ensure parameters are set
    if [[ -z "$disk" || -z "$part_num" ]]; then
        echo "Usage: partition_device <disk> <part_num>"
        return 1
    fi

    if [[ "$disk" == *nvme* ]]; then
        echo "${disk}p1"
    else
        echo "${disk}1"
    fi
}
