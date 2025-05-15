set -euox pipefail

# Postinstall script for the live system, runs in the chroot

systemctl enable whistlekube-installer.service
