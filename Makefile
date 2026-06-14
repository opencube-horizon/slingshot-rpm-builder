
.PHONY: all prepare build pkgs repo

SHS_VER := 14.0.0
LUSTRE_VER := 2.17.0

ifneq ($(NO_OVERRIDE),1)
-include Makefile.overrides.$(SHS_VER)
endif

# Handle rename: cassini2-firmware-devel → cassini-firmware-headers
# Override to cassini2-firmware-devel in Makefile.overrides.* for old releases
PKG_firmware_cassini     ?= cassini-firmware-headers

REPO_cassini-headers     := HewlettPackard/shs-cassini-headers
REPO_sl-driver           := HewlettPackard/ss-link
REPO_cxi-driver          := HewlettPackard/shs-cxi-driver
REPO_firmware_cassini    := HewlettPackard/shs-firmware-cassini2-devel
REPO_slingshot_base_link := HewlettPackard/ss-sbl
REPO_libcxi              := HewlettPackard/shs-libcxi
REPO_kfabric             := HewlettPackard/shs-kfabric
REPO_network-config      := HewlettPackard/shs-network-config
REPO_libfabric           := HewlettPackard/shs-libfabric
REPO_utils               := HewlettPackard/shs-utils
REPO_rxe                 := HewlettPackard/shs-rxe
REPO_kdreg2              := HewlettPackard/shs-kdreg2
REPO_firmware-management := HewlettPackard/shs-firmware-management
REPO_lustre              := lustre/lustre-release

REGISTRY_AND_PROJECT :=
PUSH := false
LOAD := false

ARCH := $(shell uname -m)
# or should we use `uname -p`, or `arch`?

PLATFORMS := linux/amd64,linux/arm64

# TODO: package revisions are currently hardcoded

SHS_COMPONENTS := \
  firmware_cassini \
  slingshot_base_link \
  cassini-headers \
  sl-driver \
  cxi-driver \
  libcxi \
  kfabric \
  network-config \
  utils \
  rxe \
  kdreg2 \
  firmware-management \
  libfabric

# Set default refs only if not already set
$(foreach c,$(SHS_COMPONENTS),\
  $(if $(REF_$(c)),,$(eval REF_$(c) := refs/tags/release/shs-$(SHS_VER)))\
)

# Lustre has a different default
ifeq ($(REF_lustre),)
REF_lustre := refs/tags/$(LUSTRE_VER)
endif

HASH_SUMS := sha256 sha512
PKGS := $(addsuffix -rpm,$(SHS_COMPONENTS)) lustre-rpm
SRC_DIRS := $(addprefix src/,$(SHS_COMPONENTS)) src/lustre
VERSIONS_DIR := versions
VER_FILES := $(addsuffix .$(SHS_VER),$(addprefix $(VERSIONS_DIR)/,$(SHS_COMPONENTS)))

VER_SRC_firmware_cassini    := $(PKG_firmware_cassini).spec
VER_SRC_cassini-headers     := cray-cassini-headers-public.spec
VER_SRC_sl-driver           := sl-driver.spec
VER_SRC_slingshot_base_link := cray-slingshot-base-link.spec
VER_SRC_cxi-driver          := cray-cxi-driver.spec
VER_SRC_libcxi              := cray-libcxi.spec
VER_SRC_kfabric             := cray-kfabric.spec
VER_SRC_network-config      := slingshot-network-config.spec
VER_SRC_utils               := slingshot-utils.spec
VER_SRC_rxe                 := cray-rxe-driver.spec
VER_SRC_kdreg2              := kdreg2.spec
VER_SRC_firmware-management := slingshot-firmware-management.spec
VER_SRC_libfabric           := configure.ac

firmware_cassini_ver    = $(shell cat $(VERSIONS_DIR)/firmware_cassini.$(SHS_VER))
cassini_headers_ver     = $(shell cat $(VERSIONS_DIR)/cassini-headers.$(SHS_VER))
sl_driver_ver           = $(shell cat $(VERSIONS_DIR)/sl-driver.$(SHS_VER))
slingshot_base_link_ver = $(shell cat $(VERSIONS_DIR)/slingshot_base_link.$(SHS_VER))
cxi_driver_ver          = $(shell cat $(VERSIONS_DIR)/cxi-driver.$(SHS_VER))
libcxi_ver              = $(shell cat $(VERSIONS_DIR)/libcxi.$(SHS_VER))
kfabric_ver             = $(shell cat $(VERSIONS_DIR)/kfabric.$(SHS_VER))
network_config_ver      = $(shell cat $(VERSIONS_DIR)/network-config.$(SHS_VER))
utils_ver               = $(shell cat $(VERSIONS_DIR)/utils.$(SHS_VER))
rxe_ver                 = $(shell cat $(VERSIONS_DIR)/rxe.$(SHS_VER))
kdreg2_ver              = $(shell cat $(VERSIONS_DIR)/kdreg2.$(SHS_VER))
firmware_management_ver = $(shell cat $(VERSIONS_DIR)/firmware-management.$(SHS_VER))
libfabric_ver           = $(shell cat $(VERSIONS_DIR)/libfabric.$(SHS_VER))

pkg_ver = $(firstword $(subst -, ,$*))
pkg_rev = $(lastword $(subst -, ,$*))

all: pkgs containers

containers: runtime-container runtime-devel-container ops-container

pkgs:
	docker buildx build \
		--target rpms \
		--output type=local,dest=./RPMS.$(SHS_VER) \
		--build-arg SHS_VER=$(SHS_VER) \
		$(DOCKEROPTS) \
		.

interactive:
	docker buildx build --load --target buildenv \
		--build-arg SHS_VER=$(SHS_VER) \
		-t $(REGISTRY_AND_PROJECT)slingshot-container-builder \
		.
	docker run -ti --rm $(DOCKEROPTS) \
		$(REGISTRY_AND_PROJECT)slingshot-container-builder:latest \
		/bin/bash -l

runtime-container:
	docker buildx build \
		--platform $(PLATFORMS) \
		--target runtime \
		--build-arg SHS_VER=$(SHS_VER) \
		-t $(REGISTRY_AND_PROJECT)slingshot-runtime \
		--push=$(PUSH) --load=$(LOAD) --provenance false \
		$(DOCKEROPTS) \
		.

runtime-devel-container:
	docker buildx build \
		--platform $(PLATFORMS) \
		--target runtime-dev \
		--build-arg SHS_VER=$(SHS_VER) \
		-t $(REGISTRY_AND_PROJECT)slingshot-runtime-devel \
		--push=$(PUSH) --load=$(LOAD) --provenance false \
		$(DOCKEROPTS) \
		.

ops-container:
	docker buildx build \
		--platform $(PLATFORMS) \
		--target ops \
		--build-arg SHS_VER=$(SHS_VER) \
		-t $(REGISTRY_AND_PROJECT)slingshot-ops \
		--push=$(PUSH) --load=$(LOAD) --provenance false \
		$(DOCKEROPTS) \
		.

RPMS.$(SHS_VER): pkgs

repo:
	docker buildx build \
	  --platform $(PLATFORMS) \
	  --target rpms \
	  --output type=local,dest=./RPMS.$(SHS_VER),platform-split=false \
	  --build-arg SHS_VER=$(SHS_VER) \
	  $(DOCKEROPTS) .
	rm -rf RPMS.$(SHS_VER)/repodata
	printf '%s\n' \
	    'FROM registry.opensuse.org/opensuse/leap:16.0' \
	    'RUN zypper --non-interactive install createrepo_c' \
	    'COPY . /RPMS' \
	    'RUN createrepo /RPMS' \
	    'FROM scratch' \
	    'COPY --from=0 /RPMS/repodata /repodata' \
	  | docker buildx build -f - \
	    --output type=local,dest=./RPMS.$(SHS_VER) \
	    RPMS.$(SHS_VER)
	@echo "==> Multi-arch repository ready in RPMS.$(SHS_VER)/"

.PHONY: versions
versions: $(VER_FILES)

$(VERSIONS_DIR)/%.${SHS_VER}: Makefile
	@mkdir -p versions
	@echo "Fetching version for $* from GitHub: $(REPO_$*)@$(REF_$*)" >&2
	@curl -fsSL "https://raw.githubusercontent.com/$(REPO_$*)/$(REF_$*)/$(VER_SRC_$*)" \
	  | awk '/^Version:/ {print $$2;}' > "$@"

$(VERSIONS_DIR)/libfabric.${SHS_VER}: Makefile
	@mkdir -p versions
	@echo "Fetching version for libfabric from GitHub: $(REPO_libfabric)@$(REF_libfabric)" >&2
	@curl -fsSL "https://raw.githubusercontent.com/$(REPO_libfabric)/$(REF_libfabric)/$(VER_SRC_libfabric)" \
	  | ggrep -oP '^AC_INIT[^\d]+\K[^\]]+' > "$@"

.PHONY: prepare
prepare: $(SRC_DIRS)

src/%:
	mkdir -p "$@"
	curl -L "https://github.com/$(REPO_$(notdir $@))/archive/$(REF_$(notdir $@)).tar.gz" \
		| tar -xz --strip-components=1 -C "$@"
	find patches-$(SHS_VER) -ipath '$(patsubst src/%,patches-$(SHS_VER)/%,$@)/*.patch' \
		| sort \
		| xargs -I{} sh -c 'echo "Applying: {}"; patch -d $@ -p1 < "{}"'

.PHONY: check-availabilities
check-availabilities: $(patsubst src/%,check-availability/%,$(SRC_DIRS))
check-availability/%:
	@curl -sfIL "https://github.com/$(REPO_$(notdir $@))/archive/$(REF_$(notdir $@)).tar.gz" >/dev/null \
		&& echo "✅ https://github.com/$(REPO_$(notdir $@))/archive/$(REF_$(notdir $@)).tar.gz" \
		|| echo "❌ https://github.com/$(REPO_$(notdir $@))/archive/$(REF_$(notdir $@)).tar.gz"

.PHONY: checksums
checksums: $(patsubst src/%,checksum/%,$(SRC_DIRS))
checksum/%: SHELL := /bin/bash
checksum/%:
	@command -v pee >/dev/null || { echo "'pee' from moreutils is needed"; exit 1; }
	@paste \
	  <(printf '$(subst -,_,$(notdir $@))_%s\n' $(addsuffix ":",$(HASH_SUMS))) \
	  <(curl -sL "https://github.com/$(REPO_$(notdir $@))/archive/$(REF_$(notdir $@)).tar.gz" | pee $(HASH_SUMS))

firmware_cassini-rpm: src/firmware_cassini
	# use make call to have firmware_cassini_ver available when starting this rule
	$(MAKE) rpmbuild/RPMS/noarch/$(PKG_firmware_cassini)-$(firmware_cassini_ver)-1.noarch.rpm

firmware_cassini-install: firmware_cassini-rpm
	rpm -i "rpmbuild/RPMS/noarch/$(PKG_firmware_cassini)-$(firmware_cassini_ver)-1.noarch.rpm"

rpmbuild/RPMS/noarch/$(PKG_firmware_cassini)-%.noarch.rpm:
	cd src/firmware_cassini ; chmod +x build-rpm.sh ; ./build-rpm.sh
	mkdir -p rpmbuild/RPMS/noarch
	cp src/firmware_cassini/build/rpmbuild/RPMS/noarch/$(PKG_firmware_cassini)-$*.noarch.rpm "$@"

# 'env -i' is required to avoid a failure in rpmbuild when being called via nested make calls

cassini-headers-rpm: src/cassini-headers
	$(MAKE) rpmbuild/RPMS/noarch/cray-cassini-headers-user-$(cassini_headers_ver)-0.noarch.rpm

cassini-headers-install: cassini-headers-rpm
	rpm -i --force \
		"rpmbuild/RPMS/noarch/cray-cassini-headers-user-$(cassini_headers_ver)-0.noarch.rpm" \
		"rpmbuild/RPMS/noarch/cray-cassini-csr-defs-$(cassini_headers_ver)-0.noarch.rpm"

rpmbuild/RPMS/noarch/cray-cassini-headers-user-%.noarch.rpm:
	mkdir -p rpmbuild/SOURCES rpmbuild/RPMS/noarch
	tar --transform "s,^src/cassini-headers/,cray-cassini-headers-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-cassini-headers-$(pkg_ver).tar.gz" src/cassini-headers
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/cassini-headers/cray-cassini-headers-public.spec

sl-driver-rpm: src/sl-driver cassini-headers-rpm
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/sl-driver-$(sl_driver_ver)-0.$(ARCH).rpm"

sl-driver-install: sl-driver-rpm
	rpm -i --force "rpmbuild/RPMS/$(ARCH)/sl-driver-devel-$(sl_driver_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/sl-driver-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	if [ -f src/sl-driver/knl/Makefile ]; then sed -i -e 's|\(-Werror\)|\1 -Wno-error=missing-prototypes|' src/sl-driver/knl/Makefile; fi
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

utils-rpm: src/utils
	$(MAKE) "rpmbuild/RPMS/noarch/slingshot-utils-$(utils_ver)-0.noarch.rpm"

rpmbuild/RPMS/noarch/slingshot-utils-%.noarch.rpm:
	mkdir -p rpmbuild/SOURCES rpmbuild/RPMS/noarch
	tar --transform "s,^src/utils/,slingshot-utils-$(pkg_ver)/," -cf "rpmbuild/SOURCES/slingshot-utils-$(pkg_ver).tar.gz" src/utils
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/utils/slingshot-utils.spec

rxe-rpm: src/rxe
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/cray-rxe-driver-devel-$(rxe_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/cray-rxe-driver-devel-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/rxe/,cray-rxe-driver-$(pkg_ver)/," -cf "rpmbuild/SOURCES/cray-rxe-driver-$(pkg_ver).tar.gz" src/rxe
	cp src/rxe/kmp_files src/rxe/rxe_versions rpmbuild/SOURCES/ 2>/dev/null || true
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/rxe/cray-rxe-driver.spec

kdreg2-rpm: src/kdreg2
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/kdreg2-devel-$(kdreg2_ver)-0.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/kdreg2-devel-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	tar --transform "s,^src/kdreg2/,kdreg2-$(pkg_ver)/," -cf "rpmbuild/SOURCES/kdreg2-$(pkg_ver).tar.gz" src/kdreg2
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/kdreg2/kdreg2.spec

firmware-management-rpm: src/firmware-management
	$(MAKE) "rpmbuild/RPMS/noarch/slingshot-firmware-management-$(firmware_management_ver)-0.noarch.rpm"

rpmbuild/RPMS/noarch/slingshot-firmware-management-%.noarch.rpm:
	mkdir -p rpmbuild/SOURCES rpmbuild/RPMS/noarch
	tar --transform "s,^src/firmware-management/,slingshot-firmware-management-$(pkg_ver)/," -cf "rpmbuild/SOURCES/slingshot-firmware-management-$(pkg_ver).tar.gz" src/firmware-management
	env -i BUILD_METADATA="$(pkg_rev)" PATH="$(PATH)" rpmbuild --define "_topdir $(CURDIR)/rpmbuild" -ba src/firmware-management/slingshot-firmware-management.spec

libfabric-rpm: src/libfabric libcxi-install cassini-headers-install
	$(MAKE) "rpmbuild/RPMS/$(ARCH)/libfabric-$(libfabric_ver)-1.$(ARCH).rpm"

rpmbuild/RPMS/$(ARCH)/libfabric-%.$(ARCH).rpm:
	mkdir -p rpmbuild/SOURCES "rpmbuild/RPMS/$(ARCH)"
	# Align autotools version with our desired version so make dist produces the right tarball name
	sed -i 's/AC_INIT(\[libfabric\], \[[^]]*\]/AC_INIT([libfabric], [$(pkg_ver)]/' src/libfabric/configure.ac
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
