# Debian Minimal ISO Builder

This project creates a super stripped-down Debian installer ISO with just basic systemd and essential components. It uses Makefiles and Docker to perform the build process, following modern best practices for clean, production-grade Docker build processes.

## Features

- Creates a minimal Debian installer ISO with only essential packages
- Uses Docker for a clean, reproducible build environment
- Makefile-based build system for ease of use
- Configurable build parameters
- Fully automated build process

## Requirements

- Docker
- GNU Make
- Around 10GB of free disk space for the build process

## Quick Start

To build the ISO:

```bash
make build
```

This will:
1. Build the Docker image if it doesn't exist
2. Start a Docker container
3. Run the build process inside the container
4. Output the ISO to the `output/` directory

## Build Customization

You can customize the build by editing:

- `config/packages.list`: List of packages to include
- `config/preseed.cfg`: Debian installer preseed configuration

## Makefile Targets

- `make build`: Build the ISO
- `make docker-build`: Build only the Docker image
- `make clean`: Clean up the build environment
- `make shell`: Start a shell in the Docker container for debugging
- `make help`: Show help information

## Project Structure

```
debian-minimal/
├── Makefile                # Main build orchestration
├── .dockerignore           # Docker ignore file
├── docker/
│   └── Dockerfile          # Build environment
├── scripts/
│   ├── build-iso.sh        # Main ISO creation script
│   ├── configure-chroot.sh # Chroot environment configuration
│   └── cleanup.sh          # Cleanup temporary files
├── config/
│   ├── packages.list       # Minimal package list
│   └── preseed.cfg         # Installer preseed configuration
└── README.md               # Project documentation
```

## Security Notice

The preseed configuration includes a default root password of 'whistlekube'. This is for demonstration purposes only. For production use, you should:

1. Use an encrypted password hash in the preseed file
2. Or remove the password configuration entirely and set it during first boot
3. Alternatively, use SSH keys for authentication

## License

This project is open source and available under the MIT License.
