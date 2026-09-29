# Makefile — Host-side orchestration for the Slingshot RPM builder.
#
# Thin wrapper around `docker buildx bake` (docker-bake.hcl). Bake composes the
# SHS -> middleware build as one buildkit graph, so middleware pulls the SHS
# RPMs in-graph (no ./RPMS round-trip) and everything is multi-arch by default.
# The actual package builds run *inside* the containers, driven by:
#   - Makefile.shs         — the SHS driver/library stack
#   - Makefile.middleware  — the userland/middleware stack (MPI, DAOS, ...)

.PHONY: all shs shs-local middleware middleware-local \
	containers runtime runtime-dev ops \
	interactive middleware-interactive help

SHS_VER := 14.0.1

DISTRO  ?= suse
DISTROS := suse rocky

# Multi-arch by default; override for a single-arch dev build, e.g.
# `make shs-suse PLATFORM=linux/amd64`.
PLATFORM ?= linux/amd64,linux/arm64

# Container publishing (forwarded to bake). PUSH/LOAD pick the image export.
REGISTRY_AND_PROJECT :=
PUSH := false
LOAD := false

DOCKEROPTS :=

# Select a specific buildx builder (e.g. a multi-node native multi-arch rig).
# Without it, bake uses the active builder, which may satisfy other arches via
# slow QEMU emulation instead of a native remote node.
BUILDER ?=

DOCKERFILE            = Dockerfile.$(DISTRO)
DOCKERFILE_MIDDLEWARE = Dockerfile.middleware.$(DISTRO)
RPMS_SHS              = RPMS.$(DISTRO).$(SHS_VER)
RPMS_MIDDLEWARE       = RPMS.$(DISTRO).middleware.$(SHS_VER)
CREATEREPO_IMAGE      = registry.opensuse.org/opensuse/leap:16.0
CREATEREPO_INSTALL    = zypper --non-interactive install createrepo_c

BAKE = SHS_VER=$(SHS_VER) PLATFORMS=$(PLATFORM) \
       REGISTRY_AND_PROJECT=$(REGISTRY_AND_PROJECT) PUSH=$(PUSH) LOAD=$(LOAD) \
       docker buildx bake $(if $(BUILDER),--builder $(BUILDER),) $(DOCKEROPTS)

all:
	$(BAKE) shs middleware
	$(BAKE) containers

# ─── Distro-generic implementation targets (read $(DISTRO)) ──────────────────

shs:
	$(BAKE) shs-$(DISTRO)

middleware:
	$(BAKE) middleware-$(DISTRO)

containers:
	$(BAKE) runtime-$(DISTRO) runtime-dev-$(DISTRO) ops-$(DISTRO)

runtime:
	$(BAKE) runtime-$(DISTRO)

runtime-dev:
	$(BAKE) runtime-dev-$(DISTRO)

ops:
	$(BAKE) ops-$(DISTRO)

# Merge bake's per-platform subdirs (linux_amd64/, linux_arm64/) into one flat
# RPM repository and run createrepo on it.
shs-local: shs
	rm -rf $(RPMS_SHS).local
	mkdir -p $(RPMS_SHS).local
	@for d in $(RPMS_SHS)/linux_*/; do \
	  echo "==> Merging $$d into $(RPMS_SHS).local/"; \
	  rm -rf "$$d"/repodata ; \
	  cp -a "$$d"/* $(RPMS_SHS).local/ 2>/dev/null || true ; \
	done
	docker buildx build $(if $(BUILDER),--builder $(BUILDER),) -f Dockerfile.createrepo \
		--platform linux/amd64 \
		--build-arg BASE_IMAGE=$(CREATEREPO_IMAGE) \
		--build-arg INSTALL_CMD="$(CREATEREPO_INSTALL)" \
		--output type=local,dest=./$(RPMS_SHS).local \
		$(DOCKEROPTS) \
		./$(RPMS_SHS).local
	@echo "==> Merged repository ready in $(RPMS_SHS).local/"

middleware-local: middleware
	rm -rf $(RPMS_MIDDLEWARE).local
	mkdir -p $(RPMS_MIDDLEWARE).local
	@for d in $(RPMS_MIDDLEWARE)/linux_*/; do \
	  echo "==> Merging $$d into $(RPMS_MIDDLEWARE).local/"; \
	  rm -rf "$$d"/repodata ; \
	  cp -a "$$d"/* $(RPMS_MIDDLEWARE).local/ 2>/dev/null || true ; \
	done
	docker buildx build $(if $(BUILDER),--builder $(BUILDER),) -f Dockerfile.createrepo \
		--platform linux/amd64 \
		--build-arg BASE_IMAGE=$(CREATEREPO_IMAGE) \
		--build-arg INSTALL_CMD="$(CREATEREPO_INSTALL)" \
		--output type=local,dest=./$(RPMS_MIDDLEWARE).local \
		$(DOCKEROPTS) \
		./$(RPMS_MIDDLEWARE).local
	@echo "==> Merged middleware repository ready in $(RPMS_MIDDLEWARE).local/"

# Interactive build-env shells. Not driven by bake (bake cannot `docker run`);
# single-arch host build, so the base-rpms context is a flat tree.
interactive:
	docker buildx build $(if $(BUILDER),--builder $(BUILDER),) -f $(DOCKERFILE) --load --target buildenv \
		--build-arg SHS_VER=$(SHS_VER) \
		-t $(REGISTRY_AND_PROJECT)slingshot-container-builder \
		.
	docker run -ti --rm $(DOCKEROPTS) \
		$(REGISTRY_AND_PROJECT)slingshot-container-builder:latest \
		/bin/bash -l

middleware-interactive:
	$(MAKE) shs DISTRO=$(DISTRO) PLATFORM=linux/amd64
	docker buildx build $(if $(BUILDER),--builder $(BUILDER),) -f $(DOCKERFILE_MIDDLEWARE) --load --target buildenv \
		--build-context base-rpms=./$(RPMS_SHS) \
		--build-arg SHS_VER=$(SHS_VER) \
		-t slingshot-middleware-builder \
		.
	docker run -ti --rm $(DOCKEROPTS) \
		slingshot-middleware-builder:latest \
		/bin/bash -l

# ─── Distro entrypoints (suse | rocky) ──────────────────────────────────────
# Public targets. Generated as concrete targets (one set per distro) rather
# than `%` pattern rules: GNU Make 3.81 (shipped on macOS) resolves `shs-%`
# ahead of `shs-local-%`, so pattern rules would misdispatch. Each recurses into
# the generic implementation target above with DISTRO=<distro>. Examples:
#   make shs-rocky            make shs-local-suse       make shs-shell-rocky
#   make middleware-rocky     make runtime-dev-suse     make containers-rocky
define distro-targets
.PHONY: shs-$(1) shs-local-$(1) shs-shell-$(1) \
        middleware-$(1) middleware-local-$(1) middleware-shell-$(1) \
        runtime-$(1) runtime-dev-$(1) ops-$(1) containers-$(1)
shs-$(1):              ; $$(MAKE) shs                    DISTRO=$(1)
shs-local-$(1):        ; $$(MAKE) shs-local              DISTRO=$(1)
shs-shell-$(1):        ; $$(MAKE) interactive            DISTRO=$(1)
middleware-$(1):       ; $$(MAKE) middleware             DISTRO=$(1)
middleware-local-$(1): ; $$(MAKE) middleware-local       DISTRO=$(1)
middleware-shell-$(1): ; $$(MAKE) middleware-interactive DISTRO=$(1)
runtime-$(1):          ; $$(MAKE) runtime                DISTRO=$(1)
runtime-dev-$(1):      ; $$(MAKE) runtime-dev            DISTRO=$(1)
ops-$(1):              ; $$(MAKE) ops                    DISTRO=$(1)
containers-$(1):       ; $$(MAKE) containers             DISTRO=$(1)
endef
$(foreach d,$(DISTROS),$(eval $(call distro-targets,$(d))))

help:
	@echo "Slingshot RPM builder — common targets (<distro> = $(DISTROS)):"
	@echo ""
	@echo "  Multi-arch by default; single arch via PLATFORM=linux/amd64."
	@echo "  Native multi-arch via a builder rig: BUILDER=<name> (e.g. multiarch)."
	@echo ""
	@echo "  SHS stack:"
	@echo "    shs-<distro>               build SHS RPMs        -> RPMS.<distro>.$(SHS_VER)/"
	@echo "    shs-local-<distro>         build + merge into one flat repo"
	@echo "    shs-shell-<distro>         interactive build-env shell"
	@echo ""
	@echo "  Middleware stack (MPI, DAOS, ...):"
	@echo "    middleware-<distro>        build middleware RPMs (SHS built in-graph)"
	@echo "    middleware-local-<distro>  build + merge into one flat repo"
	@echo "    middleware-shell-<distro>  interactive middleware build-env shell"
	@echo ""
	@echo "  Containers (tags: slingshot-{runtime,runtime-devel,ops}-<distro>):"
	@echo "    runtime-<distro> runtime-dev-<distro> ops-<distro>"
	@echo "    containers-<distro>        all three for one distro"
	@echo "    PUSH=true | LOAD=true      export the images"
	@echo ""
	@echo "    all                        both RPM stacks + all containers, both distros"
