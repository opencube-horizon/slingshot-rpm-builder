# Stage 1: Build environment (tools and sources, no build execution)
FROM registry.opensuse.org/opensuse/leap:16.0 AS buildenv

# BuildKit sets TARGETPLATFORM (for example linux/amd64 or linux/arm64); use it to isolate zypper caches per architecture.
ARG TARGETPLATFORM

# post-build-checks: required to get the uname hack script
# gcc13: libcxi is broken with gcc15
# kernel-default, kernel-64kb: required to get the vmlinuz image and the kernel modules
#   kernel-64kb only exists on aarch64 (64KB page size flavor)
# fuse-devel..systemd-devel: required to build libcxi
# libcurl-devel..libjson-c-devel: required to build libfabric with cxi provider
# pandoc: required for kfabric
# quilt: required for cray-rxe-driver
# openmpi4-devel..libmount-devel: required for Lustre
RUN --mount=type=cache,id=zypp-buildenv-${TARGETPLATFORM},sharing=locked,target=/var/cache/zypp \
  set -ex ; \
  zypper --non-interactive up ; \
  zypper --non-interactive install --recommends \
    -t pattern devel_{C_C++,kernel,rpm_build} ; \
  zypper --non-interactive install \
    post-build-checks \
    gcc13 \
    kernel-default \
    $(if [ "$(uname -m)" = aarch64 ]; then echo kernel-64kb kernel-64kb-devel; fi) \
    fuse-devel \
    libconfig-devel \
    libnl3-devel \
    libnuma-devel \
    libsensors4-devel \
    libuv-devel \
    libyaml-devel \
    systemd-devel \
    libcurl-devel \
    libjson-c-devel \
    pandoc-cli \
    quilt \
    openmpi4-devel \
    libmount-devel \
    ; \
  mpi-selector --verbose --system --set openmpi4

RUN /usr/lib/build/finalize-system/11-hack_uname_version_to_kernel_version

# work around https://bugzilla.opensuse.org/show_bug.cgi?id=1238724 until the fix is pushed out
RUN rm /etc/rpm/macros.leap

# make gcc-13 the default compiler for libcxi (and to match the kernel)
RUN for e in cc cpp gcc{,-ar,-nm,-ranlib} ; do ln -sf $e-13 /usr/bin/$e ; done

# createrepo_c: required for repo file creation
RUN --mount=type=cache,id=zypp-buildenv-${TARGETPLATFORM},sharing=locked,target=/var/cache/zypp \
  set -ex ; \
  zypper --non-interactive install \
    createrepo_c \
    ;

WORKDIR /build
COPY . /build/

# Stage 2: Execute the RPM build
FROM buildenv AS builder

ARG MAKEOPTS
ARG SHS_VER
RUN make rpmbuild/RPMS/repodata/repomd.xml SHS_VER=${SHS_VER} ${MAKEOPTS}

# Stage 3: Collect RPM artifacts into a minimal image
FROM scratch AS rpms
COPY --from=builder /build/rpmbuild/RPMS/ /

# Stage 4: Runtime — minimal userspace libraries for running CXI/libfabric applications
FROM registry.opensuse.org/opensuse/leap:16.0 AS runtime

ARG TARGETPLATFORM

RUN --mount=type=cache,id=zypp-runtime-${TARGETPLATFORM},sharing=locked,target=/var/cache/zypp \
    --mount=type=bind,from=rpms,target=/tmp/RPMS \
  set -ex ; \
  zypper addrepo --no-gpgcheck /tmp/RPMS slingshot ; \
  zypper --non-interactive install \
    cray-libcxi \
    libfabric \
    hwloc \
    ; \
  zypper removerepo slingshot

# Stage 5: Development — runtime + devel headers/libraries for building applications
FROM runtime AS runtime-dev

ARG TARGETPLATFORM

RUN --mount=type=cache,id=zypp-runtime-${TARGETPLATFORM},sharing=locked,target=/var/cache/zypp \
    --mount=type=bind,from=rpms,target=/tmp/RPMS \
  set -ex ; \
  zypper addrepo --no-gpgcheck /tmp/RPMS slingshot ; \
  zypper --non-interactive install \
    cray-libcxi-devel \
    libfabric-devel \
    ; \
  zypper removerepo slingshot

# Stage 6: Operations — runtime + retry handler, network config, operational tools
FROM runtime AS ops

ARG TARGETPLATFORM

RUN --mount=type=cache,id=zypp-runtime-${TARGETPLATFORM},sharing=locked,target=/var/cache/zypp \
    --mount=type=bind,from=rpms,target=/tmp/RPMS \
  set -ex ; \
  zypper addrepo --no-gpgcheck /tmp/RPMS slingshot ; \
  zypper --non-interactive install \
    cray-libcxi-utils \
    cray-libcxi-retry-handler \
    slingshot-network-config \
    open-lldp \
    iproute2 \
    iputils \
    ; \
  zypper removerepo slingshot
