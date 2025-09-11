# slingshot-rpm-builder

Single container and makefile to build Slingshot Host Software RPM packages (currently for OpenSUSE Leap 15.6 only).

## Requirements

- Docker (but can be easily adopter to Podman)
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

## Notes

- This uses the public repositories of the Slingshot Host Software packages
- The patches are from https://github.com/caps-tum/paper-2025-shs-k8s/tree/main/deployment/patches, the IEEE CLUSTER 2025 paper "Closing the HPC-Cloud Convergence Gap: Multi-Tenant Slingshot RDMA for Kubernetes".
- The main pecularity with the Makefile is the extra `$(MAKE)` call to resolve the individual package version, which can only be determined after fetching the source code.
- It is not a nice Makefile, but it works for x86_64 and aarch64 (using Docker Context and remote Docker hosts), feel free to improve.
- Keep in mind that this might likely be ported to an openSUSE Build Service or COPR at some point.
