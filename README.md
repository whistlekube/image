# Whistlekube Installer ISOs

This project creates installer ISOs for the Whistlekube OS. 

## Requirements

- Docker
- GNU Make
- Around 10GB of free disk space for the build process
- QEMU for running vm tests (optional)

## Quick Start

The build environment needs more privledges to perform bind mounts into a chroot. So we first have to create a new dockerx build server and enable it. This only has the be done once.

```bash
make init
```

Then build the ISO:

```bash
make
```

This runs a multi-stage docker buildx build which will:
1. Build chroot environments with mmdebstrap
1. Turn the chroot into a squashfs
1. Create grub bios and efi images
1. Pack everything into a bootable hybrid ISO
1. Output the ISO to the `output/` directory

## Build Customization


## Makefile Targets

- `make build`: Build the ISO
- `make clean`: Clean up the build environment (WARNING: this may blow away some unrelated things in docker)
- `make shell`: Start a shell in the Docker container for debugging
- `make help`: Show help information

## Makefile Options

See `Makefile` for all options. `BUILD_TARGET` is the most important and can be passed to `make build` or `make shell` to get outputs at different stages of the build. Targets ending with -artifact should use `make build` and will output their build artifacts to `./output`.
