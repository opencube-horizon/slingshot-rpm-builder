# Makefile — Host-side orchestration for the Slingshot RPM builder.
#
# This drives `docker buildx` to build the RPMs and container images. The actual
# package builds run *inside* the containers and are driven by:
#   - Makefile.shs         — the SHS driver/library stack
#   - Makefile.middleware  — the userland/middleware stack (MPI, DAOS, ...)

# Distro-generic implementation targets (read $(DISTRO); default suse). The
# public entrypoints are the `shs-<distro>` / `middleware-<distro>` pattern
# rules further down, which just recurse into these with DISTRO=<distro>.
.PHONY: all containers pkgs repo repo-local interactive \
	runtime-container runtime-devel-container ops-container \
	middleware middleware-interactive middleware-repo middleware-repo-local \
	help

SHS_VER := 14.0.1

DISTRO ?= suse

# Distro-specific defaults (override via rocky-* targets or command line)
DOCKERFILE             = Dockerfile.$(DISTRO)
DOCKERFILE_MIDDLEWARE  = Dockerfile.middleware.$(DISTRO)
CREATEREPO_IMAGE       = registry.opensuse.org/opensuse/leap:16.0
CREATEREPO_INSTALL     = zypper --non-interactive install createrepo_c
RPMS_PREFIX            = RPMS.$(DISTRO)
RPMS_MIDDLEWARE_PREFIX = RPMS.$(DISTRO).middleware

REGISTRY_AND_PROJECT :=
PUSH := false
LOAD := false

PLATFORM ?= linux/amd64,linux/arm64

all: pkgs containers

containers: runtime-container runtime-devel-container ops-container

pkgs:
	docker buildx build -f $(DOCKERFILE) \
		--target rpms \
		--output type=local,dest=./$(RPMS_PREFIX).$(SHS_VER) \
		--build-arg SHS_VER=$(SHS_VER) \
		--build-arg DISTRO=$(DISTRO) \
		$(DOCKEROPTS) \
		.

interactive:
	docker buildx build -f $(DOCKERFILE) --load --target buildenv \
		--build-arg SHS_VER=$(SHS_VER) \
		-t $(REGISTRY_AND_PROJECT)slingshot-container-builder \
		.
	docker run -ti --rm $(DOCKEROPTS) \
		$(REGISTRY_AND_PROJECT)slingshot-container-builder:latest \
		/bin/bash -l

runtime-container:
	docker buildx build -f $(DOCKERFILE) \
		--platform $(PLATFORM) \
		--target runtime \
		--build-arg SHS_VER=$(SHS_VER) \
		-t $(REGISTRY_AND_PROJECT)slingshot-runtime \
		--push=$(PUSH) --load=$(LOAD) --provenance false \
		$(DOCKEROPTS) \
		.

runtime-devel-container:
	docker buildx build -f $(DOCKERFILE) \
		--platform $(PLATFORM) \
		--target runtime-dev \
		--build-arg SHS_VER=$(SHS_VER) \
		-t $(REGISTRY_AND_PROJECT)slingshot-runtime-devel \
		--push=$(PUSH) --load=$(LOAD) --provenance false \
		$(DOCKEROPTS) \
		.

ops-container:
	docker buildx build -f $(DOCKERFILE) \
		--platform $(PLATFORM) \
		--target ops \
		--build-arg SHS_VER=$(SHS_VER) \
		-t $(REGISTRY_AND_PROJECT)slingshot-ops \
		--push=$(PUSH) --load=$(LOAD) --provenance false \
		$(DOCKEROPTS) \
		.

$(RPMS_PREFIX).$(SHS_VER): pkgs

repo:
	docker buildx build -f $(DOCKERFILE) \
		--platform $(PLATFORM) \
		--target rpms \
		--output type=local,dest=./$(RPMS_PREFIX).$(SHS_VER) \
		--build-arg SHS_VER=$(SHS_VER) \
		$(DOCKEROPTS) .
	@echo "==> Multi-arch RPMs ready in $(RPMS_PREFIX).$(SHS_VER)/ (per-platform subdirs)"

# Merge per-platform subdirs into a single flat RPM repository
repo-local: repo
	rm -rf $(RPMS_PREFIX).$(SHS_VER).local
	mkdir -p $(RPMS_PREFIX).$(SHS_VER).local
	@for d in $(RPMS_PREFIX).$(SHS_VER)/linux_*/; do \
	  echo "==> Merging $$d into $(RPMS_PREFIX).$(SHS_VER).local/"; \
	  rm -rf "$$d"/repodata ; \
	  cp -a "$$d"/* $(RPMS_PREFIX).$(SHS_VER).local/ 2>/dev/null || true ; \
	done
	docker buildx build -f Dockerfile.createrepo \
		--platform linux/amd64 \
		--build-arg BASE_IMAGE=$(CREATEREPO_IMAGE) \
		--build-arg INSTALL_CMD="$(CREATEREPO_INSTALL)" \
		--output type=local,dest=./$(RPMS_PREFIX).$(SHS_VER).local \
		$(DOCKEROPTS) \
		./$(RPMS_PREFIX).$(SHS_VER).local
	@echo "==> Merged repository ready in $(RPMS_PREFIX).$(SHS_VER).local/"

# ─── Middleware RPM targets (userland: MPI, DAOS, ...) ───────────────────────

middleware: $(RPMS_PREFIX).$(SHS_VER)
	docker buildx build -f $(DOCKERFILE_MIDDLEWARE) \
		--build-context base-rpms=./$(RPMS_PREFIX).$(SHS_VER) \
		--target rpms \
		--output type=local,dest=./$(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER) \
		--build-arg SHS_VER=$(SHS_VER) \
		$(DOCKEROPTS) \
		.

middleware-interactive: $(RPMS_PREFIX).$(SHS_VER)
	docker buildx build -f $(DOCKERFILE_MIDDLEWARE) --load --target buildenv \
		--build-context base-rpms=./$(RPMS_PREFIX).$(SHS_VER) \
		--build-arg SHS_VER=$(SHS_VER) \
		-t slingshot-middleware-builder \
		.
	docker run -ti --rm $(DOCKEROPTS) \
		slingshot-middleware-builder:latest \
		/bin/bash -l

middleware-repo: $(RPMS_PREFIX).$(SHS_VER)
	docker buildx build -f $(DOCKERFILE_MIDDLEWARE) \
		--platform $(PLATFORM) \
		--build-context base-rpms=./$(RPMS_PREFIX).$(SHS_VER) \
		--target rpms \
		--output type=local,dest=./$(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER) \
		--build-arg SHS_VER=$(SHS_VER) \
		$(DOCKEROPTS) .
	@echo "==> Multi-arch middleware RPMs ready in $(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER)/ (per-platform subdirs)"

middleware-repo-local: middleware-repo
	rm -rf $(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER).local
	mkdir -p $(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER).local
	@for d in $(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER)/linux_*/; do \
	  echo "==> Merging $$d into $(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER).local/"; \
	  rm -rf "$$d"/repodata ; \
	  cp -a "$$d"/* $(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER).local/ 2>/dev/null || true ; \
	done
	docker buildx build -f Dockerfile.createrepo \
		--platform linux/amd64 \
		--build-arg BASE_IMAGE=$(CREATEREPO_IMAGE) \
		--build-arg INSTALL_CMD="$(CREATEREPO_INSTALL)" \
		--output type=local,dest=./$(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER).local \
		$(DOCKEROPTS) \
		./$(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER).local
	@echo "==> Merged middleware repository ready in $(RPMS_MIDDLEWARE_PREFIX).$(SHS_VER).local/"

# ─── Distro entrypoints (suse | rocky) ──────────────────────────────────────
# Public targets. Generated as concrete targets (one set per distro) rather
# than `%` pattern rules: GNU Make 3.81 (shipped on macOS) resolves `shs-%`
# ahead of `shs-repo-%`, so pattern rules would misdispatch. Each recurses into
# the generic implementation target above with DISTRO=<distro>, so the real
# build logic (and its file-based RPM reuse) lives exactly once. Examples:
#   make shs-rocky              make shs-repo-suse       make shs-shell-rocky
#   make middleware-rocky       make middleware-repo-suse
DISTROS := suse rocky

define distro-targets
.PHONY: shs-$(1) shs-repo-$(1) shs-repo-local-$(1) shs-shell-$(1) \
        middleware-$(1) middleware-repo-$(1) middleware-repo-local-$(1) middleware-shell-$(1)
shs-$(1):                   ; $$(MAKE) pkgs                   DISTRO=$(1)
shs-repo-$(1):              ; $$(MAKE) repo                   DISTRO=$(1)
shs-repo-local-$(1):        ; $$(MAKE) repo-local             DISTRO=$(1)
shs-shell-$(1):             ; $$(MAKE) interactive            DISTRO=$(1)
middleware-$(1):            ; $$(MAKE) middleware             DISTRO=$(1)
middleware-repo-$(1):       ; $$(MAKE) middleware-repo        DISTRO=$(1)
middleware-repo-local-$(1): ; $$(MAKE) middleware-repo-local  DISTRO=$(1)
middleware-shell-$(1):      ; $$(MAKE) middleware-interactive DISTRO=$(1)
endef
$(foreach d,$(DISTROS),$(eval $(call distro-targets,$(d))))

help:
	@echo "Slingshot RPM builder — common targets (<distro> = $(DISTROS)):"
	@echo ""
	@echo "  SHS stack:"
	@echo "    shs-<distro>               build SHS RPMs (single arch)"
	@echo "    shs-repo-<distro>          build multi-arch SHS RPMs (per-platform subdirs)"
	@echo "    shs-repo-local-<distro>    build + merge into one flat repo"
	@echo "    shs-shell-<distro>         interactive build-env shell"
	@echo ""
	@echo "  Middleware stack (MPI, DAOS, ...):"
	@echo "    middleware-<distro>              build middleware RPMs"
	@echo "    middleware-repo-<distro>         build multi-arch middleware RPMs"
	@echo "    middleware-repo-local-<distro>   build + merge into one flat repo"
	@echo "    middleware-shell-<distro>        interactive middleware build-env shell"
	@echo ""
	@echo "  Containers (default DISTRO=$(DISTRO)):"
	@echo "    all                 pkgs + runtime/devel/ops containers"
	@echo "    runtime-container runtime-devel-container ops-container"
	@echo ""
	@echo "  Generic implementation targets (default DISTRO=suse): pkgs repo"
	@echo "    repo-local interactive middleware middleware-repo ..."
