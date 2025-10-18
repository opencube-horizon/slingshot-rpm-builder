
.PHONY: all prepare build pkgs

SHS_VER := 12.0.1
FIRMWARE_CASSINI_REF := 756565798aa61f114bb1c2c9af342931711e5a5e
BASE_LINK_REF := 69282a99fb6301dce5399ca15190a0c39f5c7c04
LIBFABRIC_REF := refs/heads/main
LUSTRE_VER := 2.16.1

REGISTRY_AND_PROJECT :=
PUSH := false

ARCH := $(shell uname -m)
# or should we use `uname -p`, or `arch`?

PROJECT_DIR := $(CURDIR)

# TODO: package revisions are currently hardcoded

ifeq ($(FIRMWARE_CASSINI_REF),)
FIRMWARE_CASSINI_REF := refs/tags/release/shs-$(SHS_VER)
endif

ifeq ($(BASE_LINK_REF),)
BASE_LINK_REF := refs/tags/release/shs-$(SHS_VER)
endif

ifeq ($(CASSINI_HEADERS_REF),)
CASSINI_HEADERS_REF := refs/tags/release/shs-$(SHS_VER)
endif

ifeq ($(SL_DRIVER_REF),)
SL_DRIVER_REF := refs/tags/release/shs-$(SHS_VER)
endif

ifeq ($(CXI_DRIVER_REF),)
CXI_DRIVER_REF := refs/tags/release/shs-$(SHS_VER)
endif

ifeq ($(LIBCXI_REF),)
LIBCXI_REF := refs/tags/release/shs-$(SHS_VER)
endif

ifeq ($(KFABRIC_REF),)
KFABRIC_REF := refs/tags/release/shs-$(SHS_VER)
endif

firmware_cassini_ver = $(shell awk '/^Version:/ {print $$2;}' src/firmware_cassini/cassini2-firmware-devel.spec)
cassini_headers_ver = $(shell awk '/^Version:/ {print $$2;}' src/cassini-headers/cray-cassini-headers-public.spec)
sl_driver_ver = $(shell awk '/^Version:/ {print $$2;}' src/sl-driver/sl-driver.spec)
slingshot_base_link_ver = $(shell awk '/^Version:/ {print $$2;}' src/slingshot_base_link/cray-slingshot-base-link.spec)
cxi_driver_ver = $(shell awk '/^Version:/ {print $$2;}' src/cxi-driver/cray-cxi-driver.spec)
libcxi_ver = $(shell awk '/^Version:/ {print $$2;}' src/libcxi/cray-libcxi.spec)
kfabric_ver = $(shell awk '/^Version:/ {print $$2;}' src/kfabric/cray-kfabric.spec)
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
		make libfabric-rpm lustre-rpm $(MAKEOPTS)
# libfabric automatically pulls all the others
# do not use $(MAKE) to avoid setting make level variables
# also, do not use MAKEFLAGS since the outside make and the inside might not be compatible
# NOTE: if you want to avoid refetching, bind-mount the src/ directory

runtime: RPMS
	docker buildx build -f ./Dockerfile.runtime -t $(REGISTRY_AND_PROJECT)slingshot-container-runtime . --push=$(PUSH) --provenance false

RPMS: pkgs

prepare: src/cassini-headers src/sl-driver src/cxi-driver src/firmware_cassini src/slingshot_base_link src/kfabric

src/cassini-headers:
	mkdir -p "$@"
	curl -L "https://github.com/HewlettPackard/shs-cassini-headers/archive/$(CASSINI_HEADERS_REF).tar.gz" | tar -xz --strip-components=1 -C "$@"
	find patches -ipath '$(patsubst src/%,patches/%,$@)/*.patch' | sort | xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

src/sl-driver:
	mkdir -p "$@"
	curl -L "https://github.com/HewlettPackard/ss-link/archive/$(SL_DRIVER_REF).tar.gz" | tar -xz --strip-components=1 -C "$@"
	find patches -ipath '$(patsubst src/%,patches/%,$@)/*.patch' | sort | xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

src/cxi-driver:
	mkdir -p "$@"
	curl -L "https://github.com/HewlettPackard/shs-cxi-driver/archive/$(CXI_DRIVER_REF).tar.gz" | tar -xz --strip-components=1 -C "$@"
	find patches -ipath '$(patsubst src/%,patches/%,$@)/*.patch' | sort | xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

src/firmware_cassini:
	mkdir -p "$@"
	curl -L "https://github.com/HewlettPackard/shs-firmware-cassini2-devel/archive/$(FIRMWARE_CASSINI_REF).tar.gz" | tar -xz --strip-components=1 -C "$@"
	chmod +x src/firmware_cassini/build-rpm.sh
	find patches -ipath '$(patsubst src/%,patches/%,$@)/*.patch' | sort | xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

src/slingshot_base_link:
	mkdir -p "$@"
	curl -L "https://github.com/HewlettPackard/ss-sbl/archive/$(BASE_LINK_REF).tar.gz" | tar -xz --strip-components=1 -C "$@"
	find patches -ipath '$(patsubst src/%,patches/%,$@)/*.patch' | sort | xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

src/libcxi:
	mkdir -p "$@"
	curl -L "https://github.com/HewlettPackard/shs-libcxi/archive/$(LIBCXI_REF).tar.gz" | tar -xz --strip-components=1 -C "$@"
	find patches -ipath '$(patsubst src/%,patches/%,$@)/*.patch' | sort | xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

src/kfabric:
	mkdir -p "$@"
	curl -L "https://github.com/HewlettPackard/shs-kfabric/archive/$(KFABRIC_REF).tar.gz" | tar -xz --strip-components=1 -C "$@"
	find patches -ipath '$(patsubst src/%,patches/%,$@)/*.patch' | sort | xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

src/libfabric:
	mkdir -p "$@"
	# the master is usually up-to-date with upstream libfabric, but we might want/need another branch
	curl -L "https://github.com/HewlettPackard/shs-libfabric/archive/$(LIBFABRIC_REF).tar.gz" | tar -xz --strip-components=1 -C "$@"
	find patches -ipath '$(patsubst src/%,patches/%,$@)/*.patch' | sort | xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

firmware_cassini-rpm: src/firmware_cassini
	# use make call to have firmware_cassini_ver available when starting this rule
	$(MAKE) rpmbuild/RPMS/noarch/cassini2-firmware-devel-$(firmware_cassini_ver)-1.noarch.rpm

firmware_cassini-install: firmware_cassini-rpm
	rpm -i "rpmbuild/RPMS/noarch/cassini2-firmware-devel-$(firmware_cassini_ver)-1.noarch.rpm"

rpmbuild/RPMS/noarch/cassini2-firmware-devel-%.noarch.rpm:
	cd src/firmware_cassini ; ./build-rpm.sh
	mkdir -p rpmbuild/RPMS/noarch
	cp src/firmware_cassini/build/rpmbuild/RPMS/noarch/cassini2-firmware-devel-$*.noarch.rpm "$@"

# 'env -i' is required to avoid a failure in rpmbuild when being called via nested make calls

cassini-headers-rpm: src/cassini-headers
	$(MAKE) rpmbuild/RPMS/noarch/cray-cassini-headers-user-$(cassini_headers_ver)-0.noarch.rpm

cassini-headers-install: cassini-headers-rpm
	rpm -i \
		"rpmbuild/RPMS/noarch/cray-cassini-headers-user-$(cassini_headers_ver)-0.noarch.rpm" \
		"rpmbuild/RPMS/noarch/cray-cassini-csr-defs-$(cassini_headers_ver)-0.noarch.rpm"

rpmbuild/RPMS/noarch/cray-cassini-headers-user-%.noarch.rpm:
	mkdir -p rpmbuild/SOURCES mkdir -p rpmbuild/RPMS/noarch
	tar --transform "s,^src/cassini-headers/,cray-cassini-headers-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-cassini-headers-$(pkg_ver).tar.gz" src/cassini-headers
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/cassini-headers/cray-cassini-headers-public.spec

sl-driver-rpm: src/sl-driver cassini-headers-rpm
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/sl-driver-$(sl_driver_ver)-0.$(ARCH).rpm"

sl-driver-install: sl-driver-rpm
	rpm -i "rpmbuild/RPMS/$(ARCH)/sl-driver-devel-$(sl_driver_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/sl-driver-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/sl-driver/,sl-driver-$(pkg_ver)/," -cf "rpmbuild/SOURCES/sl-driver-$(pkg_ver).tar.gz" src/sl-driver
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/sl-driver/sl-driver.spec

slingshot_base_link-rpm: src/slingshot_base_link cassini-headers-install
	$(MAKE) rpmbuild/RPMS/$(ARCH)/cray-slingshot-base-link-devel-$(slingshot_base_link_ver)-0.$(ARCH).rpm

slingshot_base_link-install: slingshot_base_link-rpm
	rpm -i "rpmbuild/RPMS/$(ARCH)/cray-slingshot-base-link-devel-$(slingshot_base_link_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/cray-slingshot-base-link-devel-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/slingshot_base_link/,cray-slingshot-base-link-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-slingshot-base-link-$(pkg_ver).tar.gz" src/slingshot_base_link
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/slingshot_base_link/cray-slingshot-base-link.spec

cxi-driver-rpm: src/cxi-driver cassini-headers-install slingshot_base_link-install sl-driver-install firmware_cassini-install
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/cray-cxi-driver-devel-$(cxi_driver_ver)-0.$(ARCH).rpm"

cxi-driver-install: cxi-driver-rpm
	rpm -i "rpmbuild/RPMS/$(ARCH)/cray-cxi-driver-devel-$(cxi_driver_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/cray-cxi-driver-devel-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/cxi-driver/,cray-cxi-driver-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-cxi-driver-$(pkg_ver).tar.gz" src/cxi-driver
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/cxi-driver/cray-cxi-driver.spec

libcxi-rpm: src/libcxi cassini-headers-install cxi-driver-install firmware_cassini-install
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/cray-libcxi-$(libcxi_ver)-0.$(ARCH).rpm"

libcxi-install: libcxi-rpm
	rpm -i \
		"rpmbuild/RPMS/$(ARCH)/cray-libcxi-$(libcxi_ver)-0.$(ARCH).rpm" \
		"rpmbuild/RPMS/$(ARCH)/cray-libcxi-devel-$(libcxi_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/cray-libcxi-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/libcxi/,libcxi-$(pkg_ver)/," -cf "rpmbuild/SOURCES/libcxi-$(pkg_ver).tar.gz" src/libcxi
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/libcxi/cray-libcxi.spec

kfabric-rpm: src/kfabric libcxi-install cxi-driver-install
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/cray-kfabric-devel-$(kfabric_ver)-0.$(ARCH).rpm"

kfabric-install: kfabric-rpm
	rpm -i "rpmbuild/RPMS/$(ARCH)/cray-kfabric-devel-$(kfabric_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/cray-kfabric-devel-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/kfabric/,cray-kfabric-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-kfabric-$(pkg_ver).tar.gz" src/kfabric
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/kfabric/cray-kfabric.spec

libfabric-rpm: src/libfabric libcxi-install cassini-headers-install
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/libfabric-$(libfabric_ver)-1.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/libfabric-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	cd src/libfabric && ./autogen.sh && ./configure && make dist
	cp "src/libfabric/libfabric-$(pkg_ver).tar.bz2" rpmbuild/SOURCES/
	env -i PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/libfabric/libfabric.spec

rpmbuild/RPMS/lustre-$(LUSTRE_VER)-1.src.rpm:
	mkdir -p rpmbuild/RPMS
	cd rpmbuild/RPMS && curl -OL https://downloads.whamcloud.com/public/lustre/latest-feature-release/sles15sp6/client/SRPMS/lustre-$(LUSTRE_VER)-1.src.rpm

lustre-rpm: SHELL := bash -l
lustre-rpm: rpmbuild/RPMS/lustre-$(LUSTRE_VER)-1.src.rpm kfabric-install
	rpm -i rpmbuild/RPMS/lustre-$(LUSTRE_VER)-1.src.rpm
	rpmbuild -ba /usr/src/packages/SPECS/lustre.spec \
	  --without servers --without l_getsepol \
	  --define "kver $(shell basename /lib/modules/*-default)" \
	  --with kfi
	cp -rv /usr/src/packages/RPMS/$(shell uname -m) rpmbuild/RPMS/
