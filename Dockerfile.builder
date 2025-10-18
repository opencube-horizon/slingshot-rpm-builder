FROM opensuse/leap:15.6

# fuse-devel..system-devel: required to build libcxi
# libcurl-devel..libjson-c-devel: required to build libfabric with cxi provider
# pandoc: required for kfabric
# openmpi4-devel..libmount-devel required for Lustre
RUN --mount=type=cache,target=/var/cache/zypp \
  set -ex ; \
  zypper --non-interactive install --recommends \
    -t pattern devel_{C_C++,kernel,rpm_build} ; \
  zypper --non-interactive install \
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
    kernel \
    libmount-devel \
    ; \
  mpi-selector --verbose --system --set openmpi4

WORKDIR /build
COPY Makefile /build/
COPY patches/ /build/patches/