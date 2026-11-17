.DEFAULT_GOAL := help
IMAGE ?= tt-gf180-env:latest
DOCKER_CLI := $(shell command -v docker)

# LibreLane's sibling containers need the same project and PDK paths as the host.
DOCKER_RUN = docker run --rm --network host \
	--user "$$(id -u):$$(id -g)" \
	--group-add "$$(stat -c %g /var/run/docker.sock)" \
	--mount type=bind,src="$(CURDIR)",dst="$(CURDIR)" \
	--mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
	--mount type=bind,src="$(DOCKER_CLI)",dst=/usr/local/bin/docker-host,readonly \
	--mount type=bind,src="$(CURDIR)/scripts/docker",dst=/usr/local/bin/docker,readonly \
	--workdir "$(CURDIR)" \
	--env HOME="$(CURDIR)/.tt-home" --env PDK_ROOT="$(CURDIR)/.pdk" \
	--env PDK=gf180mcuD
TT = $(DOCKER_RUN) $(IMAGE) ./tt/tt_tool.py --pdk gf180mcuD

.PHONY: help setup test-unit test-full harden report cmd
help:
	@echo 'make test-unit  Run arbiter/SPI cocotb tests and Python checks'
	@echo 'make test-full  Run full CPU programs with pre/post memory checks'
	@echo 'make harden  Generate the GF180 configuration and run LibreLane'
	@echo 'make report  Print synthesis and routing statistics from runs/wokwi'
	@echo 'make cmd     Open an interactive Docker shell in this project'

setup:
	@echo 'Running setup'
	@mkdir -p .tt-home .pdk
	@$(DOCKER_RUN) $(IMAGE) sh -ec 'if [ ! -e tt ]; then cp -R /ttsetup/tt-support-tools tt; fi; test -f tt/tt_tool.py'

test-full: setup
	@echo 'Running full CPU programs: load code and initial RAM, execute to HALT, check expected RAM.'
	$(DOCKER_RUN) $(IMAGE) sh -ec '\
		make -C test; \
		python -m cocotb_tools.check_results test/results.xml'

test-unit: setup
	$(DOCKER_RUN) $(IMAGE) sh -ec '\
		make -C test unit; \
		for result in test/results-arbiter.xml test/results-spi.xml; do python -m cocotb_tools.check_results "$$result"; done; \
		python -m unittest discover -s test/cocotb_benches/programs -t test; \
		python -m unittest discover -s test -p test_docker_launcher.py'

harden: setup
	$(TT) --create-user-config
	$(TT) --harden

report: setup
	$(DOCKER_RUN) $(IMAGE) sh -ec '\
		set -- runs/wokwi/*-yosys-synthesis/reports/stat.rpt; \
		if [ ! -f "$$1" ]; then echo "No synthesis report yet. Run make harden first." >&2; exit 1; fi; \
		cat "$$@"; \
		./tt/tt_tool.py --pdk gf180mcuD --print-stats'

cmd: setup
	$(DOCKER_RUN) -it $(IMAGE) bash --noprofile --norc
