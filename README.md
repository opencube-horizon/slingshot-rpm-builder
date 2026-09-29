# slingshot-rpm-builder

Containers and a Makefile to build Slingshot Host Software (SHS) RPM packages,
plus the userland/middleware stack built on top of them, for **openSUSE Leap
16.0** (`suse`) and **Rocky Linux 10.2** (`rocky`).

## Requirements

- Docker with BuildKit / `docker buildx` (Docker 19.03+; a recent buildx is recommended)
- GNU Make
- For native multi-arch builds: a multi-node `buildx` builder (see
  [Remote buildx builders](#remote-buildx-builders)); otherwise non-host
  architectures build under QEMU emulation

## Overview

Two package stacks are built inside multi-stage Docker builds:

- **SHS** — the driver/library stack (`cxi`, `libcxi`, `libfabric`, `slingshot-base-link`, ...), from `Dockerfile.<distro>`
- **middleware** — the userland stack (MPI, DAOS, ...) layered on top of the SHS RPMs, from `Dockerfile.middleware.<distro>`

`docker-bake.hcl` composes them as a single BuildKit graph: the middleware build
consumes the SHS `rpms` stage in-graph via a `base-rpms` build context, so the
base RPMs are never round-tripped through the host filesystem and the per-arch
RPM set is selected automatically for each platform. The Makefile is a thin
wrapper around `docker buildx bake`.

Builds are **multi-arch by default** (`linux/amd64,linux/arm64`). Override with
`PLATFORM` for a single architecture.

## Usage

```console
❯ make help                     # list common targets

❯ make shs-suse                 # build SHS RPMs (both arches)      -> RPMS.suse.14.0.1/
❯ make shs-rocky PLATFORM=linux/amd64   # single-arch build

❯ make middleware-suse          # build middleware RPMs; SHS is built in-graph as its base
```

Output layout:

- Multi-arch: per-platform subdirs, e.g. `RPMS.suse.14.0.1/linux_amd64/`, `RPMS.suse.14.0.1/linux_arm64/`
- Single-arch: a flat tree, `RPMS.suse.14.0.1/`
- Middleware lands in `RPMS.<distro>.middleware.<ver>/`

### Merged repository

`*-local` targets merge the per-platform subdirs into one flat directory and run
`createrepo` on it, producing a repository usable by zypper/dnf across all built
architectures:

```console
❯ make shs-local-suse           # -> RPMS.suse.14.0.1.local/ (x86_64/ aarch64/ noarch/ repodata/)
❯ make middleware-local-rocky   # -> RPMS.rocky.14.0.1.middleware.local/
```

### Interactive build-env shell

Drops into a shell inside the build environment without running the build
(single-arch, host platform):

```console
❯ make shs-shell-suse
❯ make middleware-shell-suse
```

### Container images

Each distro provides `runtime`, `runtime-dev` and `ops` images (stages in
`Dockerfile.<distro>` that install the built SHS RPMs):

```console
❯ make runtime-suse                          # build the runtime image
❯ make containers-rocky                       # runtime + runtime-dev + ops
❯ make runtime-suse LOAD=true                 # load into the local docker image store
❯ make ops-suse PUSH=true REGISTRY_AND_PROJECT=registry.example.com/proj/
```

Images are tagged `slingshot-{runtime,runtime-devel,ops}-<distro>` (prefixed by
`REGISTRY_AND_PROJECT` if set). With neither `PUSH` nor `LOAD`, the image is
built but not exported (stays in the build cache).

### Everything

```console
❯ make all                      # both RPM stacks + all container images, both distros
```

## Common variables

| Variable               | Default                     | Purpose |
|------------------------|-----------------------------|---------|
| `PLATFORM`             | `linux/amd64,linux/arm64`   | Target platform(s); set to one for a single-arch build |
| `BUILDER`              | *(none)*                    | `buildx` builder to use, e.g. `multiarch`, for native multi-arch |
| `SHS_VER`              | `14.0.1`                    | SHS version to build |
| `PUSH` / `LOAD`        | `false`                     | Export container images (push to registry / load locally) |
| `REGISTRY_AND_PROJECT` | *(empty)*                   | Image tag prefix, e.g. `registry.example.com/proj/` |
| `DOCKEROPTS`           | *(empty)*                   | Extra flags passed through to `docker buildx` |

## Remote buildx builders

Without an explicit builder, builds target the *active* `buildx` builder, which
typically satisfies non-host architectures via **slow QEMU emulation**. To build
each architecture natively, set up a multi-node builder using remote Docker hosts
over SSH and select it with `BUILDER=<name>`.

### Prerequisites

- SSH access (key-based, no passphrase) to a machine of each target architecture
- Docker installed and running on each remote machine
- Your user in the `docker` group on each remote (or rootless Docker configured)

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

```console
❯ docker buildx create --name multiarch --driver docker-container \
    --platform linux/amd64 amd64-builder
❯ docker buildx create --name multiarch --append \
    --platform linux/arm64 arm64-builder
```

Bootstrap it (pulls the buildkit image on each node and brings them online):

```console
❯ docker buildx inspect --builder multiarch --bootstrap
```

If the arm64 node is unreachable at build time, buildkit silently falls back to
emulating arm64 on the amd64 node — so confirm both nodes show as running in
`docker buildx ls`.

### 3. Use it

```console
❯ make shs-suse BUILDER=multiarch
```

(or `docker buildx use multiarch` to make it the active builder for all builds).

### Using the local machine as one of the nodes

If your local machine is one of the target architectures, use `default` as the
first node context:

```console
❯ docker buildx create --name multiarch --driver docker-container \
    --platform linux/amd64 default
❯ docker buildx create --name multiarch --append \
    --platform linux/arm64 arm64-builder
```

## Repository layout

- `Makefile` — host-side orchestration (wraps `docker buildx bake`)
- `Makefile.shs` — inner SHS build, run inside the container
- `Makefile.middleware` — inner middleware build
- `Makefile.shs.d/<ver>` — per-version SHS build overrides (only the required version is copied into the build)
- `docker-bake.hcl` — the SHS → middleware build graph and container targets
- `Dockerfile.<distro>` / `Dockerfile.middleware.<distro>` — per-distro build definitions
- `patches/<ver>/common/` and `patches/<ver>/<distro>/` — version- and distro-specific patches (only the needed version is copied in)

## Notes

- This uses the public repositories of the Slingshot Host Software packages.
- The patches are from https://github.com/caps-tum/paper-2025-shs-k8s/tree/main/deployment/patches, the IEEE CLUSTER 2025 paper "Closing the HPC-Cloud Convergence Gap: Multi-Tenant Slingshot RDMA for Kubernetes".
- A peculiarity of the inner build is the extra `$(MAKE)` call to resolve the individual package version, which can only be determined after fetching the source code.
- This might be ported to an openSUSE Build Service or COPR at some point.
