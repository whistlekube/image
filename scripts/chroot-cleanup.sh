#!/bin/bash
set -euo pipefail

# Remove unnecessary packages
echo "Removing unnecessary packages..."
apt-get remove -y --purge installation-report tasksel tasksel-data
apt-get autoremove -y --purge

# Clean apt caches to reduce image size
echo "Cleaning apt caches..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Cleanup complete."
