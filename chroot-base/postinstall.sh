#!/bin/bash
set -euox pipefail

# Set up root account (will be overridden by preseed in actual installation)
echo "root:whistlekube" | chpasswd
