#!/bin/bash

# Clean up package lists and cache
apt-get clean
rm -rf /var/lib/apt/lists/*

# Add modules to load early on boot if not handled by udev/etc
echo "8021q" > /etc/modules-load.d/firewall-net.conf
echo "bridge" >> /etc/modules-load.d/firewall-net.conf
echo "bonding" >> /etc/modules-load.d/firewall-net.conf

