
.PHONY: all prepare build pkgs

SHS_VER := 12.0.1
REF_firmware_cassini := 756565798aa61f114bb1c2c9af342931711e5a5e
REF_slingshot_base_link := 69282a99fb6301dce5399ca15190a0c39f5c7c04
REF_libfabric := refs/heads/main
LUSTRE_VER := 2.16.61

REPO_cassini-headers     := HewlettPackard/shs-cassini-headers
REPO_sl-driver           := HewlettPackard/ss-link
REPO_cxi-driver          := HewlettPackard/shs-cxi-driver
REPO_firmware_cassini    := HewlettPackard/shs-firmware-cassini2-devel
REPO_slingshot_base_link := HewlettPackard/ss-sbl
REPO_libcxi              := HewlettPackard/shs-libcxi
REPO_kfabric             := HewlettPackard/shs-kfabric
REPO_network-config      := HewlettPackard/shs-network-config
REPO_libfabric           := HewlettPackard/shs-libfabric
REPO_lustre              := lustre/lustre-release

REGISTRY_AND_PROJECT :=
PUSH := false

ARCH := $(shell uname -m)
# or should we use `uname -p`, or `arch`?

PROJECT_DIR := $(CURDIR)

# TODO: package revisions are currently hardcoded

SHS_COMPONENTS := \
  firmware_cassini \
  slingshot_base_link \
  cassini-headers \
  sl-driver \
  cxi-driver \
  libcxi \
  kfabric \
  network-config

# Set default refs only if not already set
$(foreach c,$(SHS_COMPONENTS),\
  $(if $(REF_$(c)),,$(eval REF_$(c) := refs/tags/release/shs-$(SHS_VER)))\
)

# Lustre has a different default
ifeq ($(REF_lustre),)
REF_lustre := refs/tags/$(LUSTRE_VER)
endif

PKGS := $(addsuffix -rpm,$(SHS_COMPONENTS)) lustre-rpm
SRC_DIRS := $(addprefix src/,$(SHS_COMPONENTS)) src/lustre

# The components have their own versions, extract them here
firmware_cassini_ver = $(shell awk '/^Version:/ {print $$2;}' src/firmware_cassini/cassini2-firmware-devel.spec)
cassini_headers_ver = $(shell awk '/^Version:/ {print $$2;}' src/cassini-headers/cray-cassini-headers-public.spec)
sl_driver_ver = $(shell awk '/^Version:/ {print $$2;}' src/sl-driver/sl-driver.spec)
slingshot_base_link_ver = $(shell awk '/^Version:/ {print $$2;}' src/slingshot_base_link/cray-slingshot-base-link.spec)
cxi_driver_ver = $(shell awk '/^Version:/ {print $$2;}' src/cxi-driver/cray-cxi-driver.spec)
libcxi_ver = $(shell awk '/^Version:/ {print $$2;}' src/libcxi/cray-libcxi.spec)
kfabric_ver = $(shell awk '/^Version:/ {print $$2;}' src/kfabric/cray-kfabric.spec)
network_config_ver = $(shell awk '/^Version:/ {print $$2;}' src/network-config/slingshot-network-config.spec)
libfabric_ver = $(shell grep -oP '^AC_INIT[^\d]+\K[^\]]+' src/libfabric/configure.ac 2>/dev/null)

pkg_ver = $(firstword $(subst -, ,$*))
pkg_rev = $(lastword $(subst -, ,$*))

all: pkgs runtime

pkgs:
	docker buildx build -f ./Dockerfile.builder -t $(REGISTRY_AND_PROJECT)slingshot-container-builder .
	mkdir -p RPMS
	docker run -ti --rm $(DOCKEROPTS) \
		-v "$(PROJECT_DIR)/RPMS/:/build/rpmbuild/RPMS" \
		$(REGISTRY_AND_PROJECT)slingshot-container-builder:latest \
		make $(PKGS) rpmbuild/RPMS/repodata/repomd.xml $(MAKEOPTS)
# do not use $(MAKE) to avoid setting make level variables
# also, do not use MAKEFLAGS since the outside make and the inside might not be compatible
# NOTE: if you want to avoid refetching, bind-mount the src/ directory

interactive:
	docker buildx build -f ./Dockerfile.builder -t $(REGISTRY_AND_PROJECT)slingshot-container-builder .
	mkdir -p RPMS
	docker run -ti --rm $(DOCKEROPTS) \
		-v "$(PROJECT_DIR)/RPMS/:/build/rpmbuild/RPMS" \
		$(REGISTRY_AND_PROJECT)slingshot-container-builder:latest \
		/bin/bash -l

runtime: RPMS
	docker buildx build -f ./Dockerfile.runtime -t $(REGISTRY_AND_PROJECT)slingshot-container-runtime . --push=$(PUSH) --provenance false

RPMS: pkgs

.PHONY: prepare
prepare: $(SRC_DIRS)

src/%:
	mkdir -p "$@"
	curl -L "https://github.com/$(REPO_$(notdir $@))/archive/$(REF_$(notdir $@)).tar.gz" \
		| tar -xz --strip-components=1 -C "$@"
	find patches -ipath '$(patsubst src/%,patches/%,$@)/*.patch' \
		| sort \
		| xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

.PHONY: check-availabilities
check-availabilities: $(patsubst src/%,check-availability/%,$(SRC_DIRS))
check-availability/%:
	curl -sfIL "https://github.com/$(REPO_$(notdir $@))/archive/$(REF_$(notdir $@)).tar.gz" >/dev/null

firmware_cassini-rpm: src/firmware_cassini
	# use make call to have firmware_cassini_ver available when starting this rule
	$(MAKE) rpmbuild/RPMS/noarch/cassini2-firmware-devel-$(firmware_cassini_ver)-1.noarch.rpm

firmware_cassini-install: firmware_cassini-rpm
	rpm -i "rpmbuild/RPMS/noarch/cassini2-firmware-devel-$(firmware_cassini_ver)-1.noarch.rpm"

rpmbuild/RPMS/noarch/cassini2-firmware-devel-%.noarch.rpm:
	cd src/firmware_cassini ; chmod +x build-rpm.sh ; ./build-rpm.sh
	mkdir -p rpmbuild/RPMS/noarch
	cp src/firmware_cassini/build/rpmbuild/RPMS/noarch/cassini2-firmware-devel-$*.noarch.rpm "$@"

# 'env -i' is required to avoid a failure in rpmbuild when being called via nested make calls

cassini-headers-rpm: src/cassini-headers
	$(MAKE) rpmbuild/RPMS/noarch/cray-cassini-headers-user-$(cassini_headers_ver)-0.noarch.rpm

cassini-headers-install: cassini-headers-rpm
	rpm -i --force \
		"rpmbuild/RPMS/noarch/cray-cassini-headers-user-$(cassini_headers_ver)-0.noarch.rpm" \
		"rpmbuild/RPMS/noarch/cray-cassini-csr-defs-$(cassini_headers_ver)-0.noarch.rpm"

rpmbuild/RPMS/noarch/cray-cassini-headers-user-%.noarch.rpm:
	mkdir -p rpmbuild/SOURCES mkdir -p rpmbuild/RPMS/noarch
	tar --transform "s,^src/cassini-headers/,cray-cassini-headers-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-cassini-headers-$(pkg_ver).tar.gz" src/cassini-headers
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/cassini-headers/cray-cassini-headers-public.spec

sl-driver-rpm: src/sl-driver cassini-headers-rpm
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/sl-driver-$(sl_driver_ver)-0.$(ARCH).rpm"

sl-driver-install: sl-driver-rpm
	rpm -i --force "rpmbuild/RPMS/$(ARCH)/sl-driver-devel-$(sl_driver_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/sl-driver-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	sed -i -e 's|\(-Werror\)|\1 -Wno-error=missing-prototypes|' src/sl-driver/knl/Makefile
	tar --transform "s,^src/sl-driver/,sl-driver-$(pkg_ver)/," -cf "rpmbuild/SOURCES/sl-driver-$(pkg_ver).tar.gz" src/sl-driver
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/sl-driver/sl-driver.spec

slingshot_base_link-rpm: src/slingshot_base_link cassini-headers-install
	$(MAKE) rpmbuild/RPMS/$(ARCH)/cray-slingshot-base-link-devel-$(slingshot_base_link_ver)-0.$(ARCH).rpm

slingshot_base_link-install: slingshot_base_link-rpm
	rpm -i --force "rpmbuild/RPMS/$(ARCH)/cray-slingshot-base-link-devel-$(slingshot_base_link_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/cray-slingshot-base-link-devel-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	# recent compilers error out on missing prototypes
	sed -i -e 's|\(-Werror\)$$|\1 -Wno-error=missing-prototypes|' src/slingshot_base_link/Makefile
	tar --transform "s,^src/slingshot_base_link/,cray-slingshot-base-link-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-slingshot-base-link-$(pkg_ver).tar.gz" src/slingshot_base_link
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/slingshot_base_link/cray-slingshot-base-link.spec

cxi-driver-rpm: src/cxi-driver cassini-headers-install slingshot_base_link-install sl-driver-install firmware_cassini-install
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/cray-cxi-driver-devel-$(cxi_driver_ver)-0.$(ARCH).rpm"

cxi-driver-install: cxi-driver-rpm
	rpm -i --force "rpmbuild/RPMS/$(ARCH)/cray-cxi-driver-devel-$(cxi_driver_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/cray-cxi-driver-devel-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/cxi-driver/,cray-cxi-driver-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-cxi-driver-$(pkg_ver).tar.gz" src/cxi-driver
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/cxi-driver/cray-cxi-driver.spec

libcxi-rpm: src/libcxi cassini-headers-install cxi-driver-install firmware_cassini-install
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/cray-libcxi-$(libcxi_ver)-0.$(ARCH).rpm"

libcxi-install: libcxi-rpm
	rpm -i --force \
		"rpmbuild/RPMS/$(ARCH)/cray-libcxi-$(libcxi_ver)-0.$(ARCH).rpm" \
		"rpmbuild/RPMS/$(ARCH)/cray-libcxi-devel-$(libcxi_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/cray-libcxi-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/libcxi/,libcxi-$(pkg_ver)/," -cf "rpmbuild/SOURCES/libcxi-$(pkg_ver).tar.gz" src/libcxi
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" \
	  rpmbuild \
	  --define "_topdir $(CURDIR)/rpmbuild" \
	  -ba src/libcxi/cray-libcxi.spec

kfabric-rpm: src/kfabric libcxi-install cxi-driver-install
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/cray-kfabric-devel-$(kfabric_ver)-0.$(ARCH).rpm"

kfabric-install: kfabric-rpm
	rpm -i --force "rpmbuild/RPMS/$(ARCH)/cray-kfabric-devel-$(kfabric_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/cray-kfabric-devel-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/kfabric/,cray-kfabric-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-kfabric-$(pkg_ver).tar.gz" src/kfabric
	sed -i -e 's|\(KCPPFLAGS\)=\(-I%{_includedir}\)|\1="\2 -Wno-missing-prototypes"|' src/kfabric/cray-kfabric.spec
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/kfabric/cray-kfabric.spec

network-config-rpm: src/network-config
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/slingshot-network-config-$(network_config_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/slingshot-network-config-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/network-config/,slingshot-network-config-$(pkg_ver)/," -cf "rpmbuild/SOURCES/slingshot-network-config-$(pkg_ver).tar.gz" src/network-config
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/network-config/slingshot-network-config.spec

libfabric-rpm: src/libfabric libcxi-install cassini-headers-install
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/libfabric-$(libfabric_ver)-1.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/libfabric-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	cd src/libfabric && ./autogen.sh && ./configure && make dist
	cp "src/libfabric/libfabric-$(pkg_ver).tar.bz2" rpmbuild/SOURCES/
	env -i PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/libfabric/libfabric.spec

lustre-rpm: SHELL := bash -l
lustre-rpm: src/lustre kfabric-install
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	cd src/lustre && ./autogen.sh && ./configure --enable-dist && make dist
	cp src/lustre/rpm/* "src/lustre/lustre-$(LUSTRE_VER).tar.gz" rpmbuild/SOURCES/
	# The newer compiler chokes on the missing prototypes.
	sed -i \
	  -e 's|-Werror|-Werror -Wno-error=missing-prototypes|' \
	  src/lustre/lustre.spec
	rpmbuild \
	  --define "_topdir $(CURDIR)/rpmbuild" \
	  -ba src/lustre/lustre.spec \
	  --without servers --without l_getsepol \
	  --define "kver $(notdir $(wildcard /lib/modules/*-default))" \
	  --with kfi

rpmbuild/RPMS/repodata/repomd.xml: $(PKGS)
	createrepo rpmbuild/RPMS
