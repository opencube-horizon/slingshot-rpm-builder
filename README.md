# slingshot-rpm-builder

Single container and makefile to build Slingshot Host Software RPM packages (currently for OpenSUSE Leap 16.0 only).

## Requirements

- Docker with BuildKit support (Docker 18.09+)
- GNU Make


## Usage

```console
❯ make
...
❯ ls RPMS/*/*
RPMS/noarch/cassini2-firmware-devel-0.1-1.noarch.rpm                            RPMS/x86_64/cray-libcxi-devel-static-1.0.2-0.x86_64.rpm
RPMS/noarch/cray-cassini-csr-defs-1.1.1-0.noarch.rpm                            RPMS/x86_64/cray-libcxi-dracut-1.0.2-0.x86_64.rpm
RPMS/noarch/cray-cassini-headers-user-1.1.1-0.noarch.rpm                        RPMS/x86_64/cray-libcxi-retry-handler-1.0.2-0.x86_64.rpm
RPMS/noarch/cray-cxi-driver-dkms-1.0.0-0.noarch.rpm                             RPMS/x86_64/cray-libcxi-utils-1.0.2-0.x86_64.rpm
RPMS/noarch/cray-slingshot-base-link-dkms-1.0.0-0.noarch.rpm                    RPMS/x86_64/cray-slingshot-base-link-devel-1.0.0-0.x86_64.rpm
RPMS/noarch/sl-driver-dkms-1.20.1-0.noarch.rpm                                  RPMS/x86_64/cray-slingshot-base-link-kmp-default-1.0.0_k6.4.0_150600.23.65-0.x86_64.rpm
RPMS/x86_64/cray-cxi-driver-devel-1.0.0-0.x86_64.rpm                            RPMS/x86_64/libfabric-2.3.0rc1-1.x86_64.rpm
RPMS/x86_64/cray-cxi-driver-kmp-default-1.0.0_k6.4.0_150600.23.65-0.x86_64.rpm  RPMS/x86_64/libfabric-devel-2.3.0rc1-1.x86_64.rpm
RPMS/x86_64/cray-cxi-driver-udev-1.0.0-0.x86_64.rpm                             RPMS/x86_64/sl-driver-1.20.1-0.x86_64.rpm
RPMS/x86_64/cray-libcxi-1.0.2-0.x86_64.rpm                                      RPMS/x86_64/sl-driver-devel-1.20.1-0.x86_64.rpm
RPMS/x86_64/cray-libcxi-devel-1.0.2-0.x86_64.rpm                                RPMS/x86_64/sl-driver-kmp-default-1.20.1_k6.4.0_150600.23.65-0.x86_64.rpm
```

For interactive debugging, `make interactive` drops into a shell inside the build environment (without running the build):

```console
❯ make interactive
```

## Build architecture

The build uses a multi-stage Docker build (defined in `Dockerfile`):

1. **`buildenv` stage** -- installs all build dependencies (compilers, kernel headers, dev libraries)
2. **`builder` stage** -- runs `make` to fetch sources, apply patches, and build all RPMs
3. **`rpms` stage** -- a `FROM scratch` image containing only the built RPMs and repo metadata

RPMs are extracted from the final stage to the host via `docker buildx build --output type=local,dest=./RPMS`, eliminating the need for host bind-mounts and enabling remote Docker daemon / CI builds.

## Remote buildx builders

To build natively on both x86_64 and aarch64 without emulation, set up a multi-node buildx builder using remote Docker hosts via SSH.

### Prerequisites

- SSH access (key-based, no passphrase) to machines of each target architecture
- Docker installed and running on each remote machine
- Your user must be in the `docker` group on each remote (or have rootless Docker configured)

### 1. Create Docker contexts for each remote host

```console
❯ docker context create amd64-builder --docker "host=ssh://user@amd64-host.example.com"
❯ docker context create arm64-builder --docker "host=ssh://user@arm64-host.example.com"
```

Verify connectivity:

```console
❯ docker --context amd64-builder info --format '{{.Architecture}}'
x86_64
❯ docker --context arm64-builder info --format '{{.Architecture}}'
aarch64
```

### 2. Create a multi-node buildx builder

Create the builder with the first node, then append additional nodes:

```console
❯ docker buildx create --name multiarch --driver docker-container \
    --platform linux/amd64 amd64-builder
❯ docker buildx create --name multiarch --append \
    --platform linux/arm64 arm64-builder
```

Inspect and bootstrap the builder (this pulls the buildkit image on each node):

```console
❯ docker buildx inspect --builder multiarch --bootstrap
Name:          multiarch
Driver:        docker-container
...
Nodes:
Name:          multiarch0
Endpoint:      amd64-builder
Platforms:     linux/amd64
...
Name:          multiarch1
Endpoint:      arm64-builder
Platforms:     linux/arm64
...
```

### 3. Set it as the active builder

```console
❯ docker buildx use multiarch
```

Or pass `DOCKEROPTS="--builder multiarch"` to `make`.

### Using the local machine as one of the nodes

If your local machine is one of the target architectures (e.g., x86_64), you can use `default` as the first node context:

```console
❯ docker buildx create --name multiarch --driver docker-container \
    --platform linux/amd64 default
❯ docker buildx create --name multiarch --append \
    --platform linux/arm64 arm64-builder
```

## Multi-architecture RPM repository

To build RPMs for all architectures and produce a single merged repository:

```console
❯ make repo
```

This:

1. Builds RPMs for each platform listed in `MULTIARCH_PLATFORMS` (default: `linux/amd64 linux/arm64`), dispatching each build to the appropriate buildx node
2. Extracts per-platform RPMs to temporary staging directories (`RPMS.amd64/`, `RPMS.arm64/`)
3. Merges all RPMs (arch-specific and noarch) into a single `RPMS/` directory
4. Runs `createrepo` on the merged directory to produce unified repository metadata
5. Cleans up the staging directories

The resulting `RPMS/` directory contains a complete RPM repository usable by zypper/dnf across all built architectures:

```
RPMS/
  x86_64/   -- x86_64 RPMs
  aarch64/  -- aarch64 RPMs
  noarch/   -- architecture-independent RPMs
  repodata/ -- unified repository metadata
```

To customise which platforms are built:

```console
❯ make repo MULTIARCH_PLATFORMS="linux/amd64"
```

## Notes

- This uses the public repositories of the Slingshot Host Software packages
- The patches are from https://github.com/caps-tum/paper-2025-shs-k8s/tree/main/deployment/patches, the IEEE CLUSTER 2025 paper "Closing the HPC-Cloud Convergence Gap: Multi-Tenant Slingshot RDMA for Kubernetes".
- The main pecularity with the Makefile is the extra `$(MAKE)` call to resolve the individual package version, which can only be determined after fetching the source code.
- It is not a nice Makefile, but it works for x86_64 and aarch64 (using Docker Context and remote Docker hosts), feel free to improve.
- Keep in mind that this might likely be ported to an openSUSE Build Service or COPR at some point.
