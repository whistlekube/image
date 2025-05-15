#!/bin/bash
set -euox pipefail

# Set up root account (will be overridden by preseed in actual installation)
#echo "root:whistlekube" | chpasswd

# Configure locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
