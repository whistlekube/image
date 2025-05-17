#!/bin/sh

set -eux

rootdir="$1"

## Create essential files
#mkdir -p "$rootdir/bin"
#echo root:x:0:0:root:/root:/bin/sh > "$rootdir/etc/passwd"
#cat << END > "$rootdir/etc/group"
#root:x:0:
#mail:x:8:
#utmp:x:43:
#E