#!/bin/bash

# Clean up package lists and cache
apt-get clean
rm -rf /var/lib/apt/lists/*
