# Stage 1: Build environment (tools and sources, no build execution)
FROM registry.opensuse.org/opensuse/leap:16.0 AS buildenv

# post-build-checks: required to get the uname hack script
# gcc13: libcxi is broken with gcc15
# kernel-default: required to get the vmlinuz image and the kernel modules
# fuse-devel..systemd-devel: required to build libcxi
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
    gcc13 \
    kernel-default \
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
RUN --mount=type=cache,target=/var/cache/zypp \
  set -ex ; \
  zypper --non-interactive install \
    createrepo_c \
    ;

WORKDIR /build
COPY . /build/

# Stage 2: Execute the RPM build
FROM buildenv AS builder

ARG MAKEOPTS
RUN make rpmbuild/RPMS/repodata/repomd.xml ${MAKEOPTS}

# Stage 3: Collect RPM artifacts into a minimal image
FROM scratch AS rpms
COPY --from=builder /build/rpmbuild/RPMS/ /
