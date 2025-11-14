FROM registry.opensuse.org/opensuse/leap:16.0

# kernel-default: required to get the vmlinuz image and the kernel modules
# fuse-devel..system-devel: required to build libcxi
# libcurl-devel..libjson-c-devel: required to build libfabric with cxi provider
# pandoc: required for kfabric
# openmpi4-devel..libmount-devel: required for Lustre
RUN --mount=type=cache,target=/var/cache/zypp \
  set -ex ; \
  zypper --non-interactive up ; \
  zypper --non-interactive install --recommends \
    -t pattern devel_{C_C++,kernel,rpm_build} ; \
  zypper --non-interactive install \
    post-build-checks \
    kernel-default \
    fuse-devel \
    libconfig-devel \
    libnl3-devel \
    libnuma-devel \
    libsensors4-devel \
    libuv-devel \
    libyaml-devel \
    systemd-devel \
    curl-devel \
    libjson-c-devel \
    pandoc-cli \
    openmpi4-devel \
    libmount-devel \
    ; \
  mpi-selector --verbose --system --set openmpi4

RUN /usr/lib/build/finalize-system/11-hack_uname_version_to_kernel_version

# createrepo_c: required for repo file creation
RUN --mount=type=cache,target=/var/cache/zypp \
  set -ex ; \
  zypper --non-interactive install \
    createrepo_c \
    ;

WORKDIR /build
COPY Makefile /build/
COPY patches/ /build/patches/