# docker-bake.hcl — Compose the SHS → middleware build graph as ONE buildkit
# graph, without the ./RPMS.* disk round-trip.
#
# Build stages are file-scoped: Dockerfile.middleware.<distro> cannot
# `COPY --from=` a stage in Dockerfile.<distro>. Bake bridges the two files
# with `contexts = { base-rpms = "target:shs-<distro>" }`: the middleware build
# consumes the `rpms` stage of the SHS build in-graph. Buildkit resolves that
# context per target platform, so it is multi-arch aware and never
# exports/re-imports the base RPMs through the host filesystem.
#
# Usage:
#   docker buildx bake shs                 # SHS RPMs for both distros  -> ./RPMS.<distro>.<ver>
#   docker buildx bake middleware          # middleware RPMs (builds shs in-graph as context)
#   docker buildx bake shs-suse            # a single matrix target
#   docker buildx bake middleware-rocky
#   docker buildx bake                     # default group: shs + middleware, both distros
#
#   # single-arch dev build (no docker-container builder / remote nodes needed):
#   docker buildx bake --set "*.platform=linux/amd64" middleware-suse
#
#   # override version / distro set:
#   docker buildx bake --set "*.args.SHS_VER=13.1.0" shs
#   SHS_VER=13.1.0 docker buildx bake shs

variable "SHS_VER" {
  default = "14.0.1"
}

variable "DISTROS" {
  default = ["suse", "rocky"]
}

# Comma-separated so it can be overridden from a plain env var / make variable
# (bake env overrides match by name); split() turns it into the list bake wants.
variable "PLATFORMS" {
  default = "linux/amd64,linux/arm64"
}

# Container image publishing knobs (mirror the Makefile). With neither PUSH nor
# LOAD, the multi-arch image is built but not exported (stays in build cache) —
# same as `docker buildx build` without --push/--load.
variable "REGISTRY_AND_PROJECT" {
  default = ""
}
variable "PUSH" {
  default = false
}
variable "LOAD" {
  default = false
}

# `bake` (no target) builds both RPM stacks for every distro. Each matrix target
# below auto-creates a group under its base name (`shs`, `middleware`,
# `runtime`, `runtime-dev`, `ops`), so `bake shs` / `bake runtime` also work.
group "default" {
  targets = ["shs", "middleware"]
}

group "containers" {
  targets = ["runtime", "runtime-dev", "ops"]
}

# ── SHS driver/library stack ────────────────────────────────────────────────
# Emits the `rpms` scratch stage (RPM tree at image root: /<arch>/, /noarch/).
target "shs" {
  name       = "shs-${distro}"
  matrix     = { distro = DISTROS }
  dockerfile = "Dockerfile.${distro}"
  context    = "."
  target     = "rpms"
  platforms  = split(",", PLATFORMS)
  args = {
    SHS_VER = SHS_VER
    DISTRO  = distro
  }
  # Only applied when shs-<distro> is a requested target; when it is pulled in
  # purely as middleware's `base-rpms` context, this export is skipped.
  output = ["type=local,dest=./RPMS.${distro}.${SHS_VER}"]
}

# ── Middleware / userland stack (MPI, DAOS, ...) ─────────────────────────────
# `base-rpms` is wired to the SHS `rpms` stage — no ./RPMS round-trip, and the
# per-arch RPM set is selected automatically for each platform.
target "middleware" {
  name       = "middleware-${distro}"
  matrix     = { distro = DISTROS }
  dockerfile = "Dockerfile.middleware.${distro}"
  context    = "."
  target     = "rpms"
  platforms  = split(",", PLATFORMS)
  contexts = {
    base-rpms = "target:shs-${distro}"
  }
  args = {
    SHS_VER = SHS_VER
  }
  output = ["type=local,dest=./RPMS.${distro}.middleware.${SHS_VER}"]
}

# ── Container images ─────────────────────────────────────────────────────────
# Each image is a stage in Dockerfile.<distro> that consumes the SHS `rpms`
# stage in-graph, so no context wiring is needed. PUSH/LOAD pick the export.
target "_container" {
  context    = "."
  platforms  = split(",", PLATFORMS)
  provenance = false
  output     = [PUSH ? "type=registry" : (LOAD ? "type=docker" : "type=cacheonly")]
}

target "runtime" {
  name       = "runtime-${distro}"
  matrix     = { distro = DISTROS }
  inherits   = ["_container"]
  dockerfile = "Dockerfile.${distro}"
  target     = "runtime"
  args = {
    SHS_VER = SHS_VER
    DISTRO  = distro
  }
  tags = ["${REGISTRY_AND_PROJECT}slingshot-runtime-${distro}"]
}

target "runtime-dev" {
  name       = "runtime-dev-${distro}"
  matrix     = { distro = DISTROS }
  inherits   = ["_container"]
  dockerfile = "Dockerfile.${distro}"
  target     = "runtime-dev"
  args = {
    SHS_VER = SHS_VER
    DISTRO  = distro
  }
  tags = ["${REGISTRY_AND_PROJECT}slingshot-runtime-devel-${distro}"]
}

target "ops" {
  name       = "ops-${distro}"
  matrix     = { distro = DISTROS }
  inherits   = ["_container"]
  dockerfile = "Dockerfile.${distro}"
  target     = "ops"
  args = {
    SHS_VER = SHS_VER
    DISTRO  = distro
  }
  tags = ["${REGISTRY_AND_PROJECT}slingshot-ops-${distro}"]
}
