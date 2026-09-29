PYTHON := python3

.PHONY: setup venv check-uv deploy-from-local deploy-from-images deploy-from-repo

setup: .ansible-collections.stamp

check-uv:
	@command -v uv >/dev/null 2>&1 || { echo "ERROR: 'uv' not found" >&2; exit 1; }

.venv: | check-uv
	uv venv -p "$(PYTHON)"

.pip-install.stamp: requirements.txt .venv | check-uv
	uv pip install --only-binary :all: -r requirements.txt
	touch $@

venv: .pip-install.stamp

.ansible-collections.stamp: requirements.yml | venv
	uv run ansible-galaxy collection install -r requirements.yml
	touch $@

# Deploy the role from this repo's local RPM build output.
#   make deploy-from-local HOSTS=cn01,
#   make deploy-from-local HOSTS=cn01, ARGS="-u root --check --diff"
HOSTS ?=
ARGS ?=

deploy-from-local: setup
	uv run ansible-playbook -i '$(HOSTS)' -e slingshot_host_rpm_source=local_dir $(ARGS) site.yml

# Deploy from OCI images: RPM_IMAGE holds the RPM tree, FIRMWARE_IMAGE the firmware RPMs.
#   make deploy-from-images HOSTS=cn01, RPM_IMAGE=reg/shs-rpms:14.0.1 FIRMWARE_IMAGE=reg/shs-fw:14.0.1
RPM_IMAGE ?=
FIRMWARE_IMAGE ?=

deploy-from-images: setup
	uv run ansible-playbook -i '$(HOSTS)' \
		-e slingshot_host_rpm_source=image \
		-e slingshot_host_rpm_image=$(RPM_IMAGE) \
		-e slingshot_host_firmware_image=$(FIRMWARE_IMAGE) \
		$(ARGS) site.yml

# Deploy from an existing repository (firmware is expected to ship in that repo).
# Uses the role's default repo URL unless REPO_URL is set.
#   make deploy-from-repo HOSTS=cn01,
#   make deploy-from-repo HOSTS=cn01, REPO_URL=https://example/repo
REPO_URL ?=

deploy-from-repo: setup
	uv run ansible-playbook -i '$(HOSTS)' -e slingshot_host_rpm_source=repo \
		$(if $(REPO_URL),-e slingshot_host_repo_url=$(REPO_URL),) $(ARGS) site.yml
