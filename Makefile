# SPDX-License-Identifier: MIT

PYTHON ?= python3
IMAGE ?= vhdl-ethernet-ghdl
TB ?=
VHDL_STD ?= 08

ifeq ($(strip $(TB)),)
TB_ARGS :=
else
TB_ARGS := $(foreach tb,$(TB),--tb $(tb))
endif

.PHONY: help list lint verify test test-ghdl test-modelsim docker-build docker-test clean

help:
	@printf '%s\n' \
		'VHDL Ethernet commands:' \
		'  make list           List source files and testbenches' \
		'  make lint           Run repo-local lint checks' \
		'  make verify         Run lint and the simulator suite' \
		'  make test           Run tests with GHDL if present, otherwise ModelSim' \
		'  make test-ghdl      Run tests with GHDL' \
		'  make test-modelsim  Run tests with ModelSim/Questa CLI' \
		'  make docker-build   Build the local GHDL test image' \
		'  make docker-test    Run the suite inside Docker' \
		'  make clean          Remove build products' \
		'' \
		'Optional: TB="tb_fcs tb_arp" limits the test selection.' \
		'Optional: VHDL_STD=19 tries VHDL-2019 with simulators that support it.'

list:
	$(PYTHON) scripts/vhdl_cli.py list

lint:
	$(PYTHON) scripts/lint.py

verify: lint test

test:
	$(PYTHON) scripts/vhdl_cli.py test --std $(VHDL_STD) $(TB_ARGS)

test-ghdl:
	$(PYTHON) scripts/vhdl_cli.py test --sim ghdl --std $(VHDL_STD) $(TB_ARGS)

test-modelsim:
	$(PYTHON) scripts/vhdl_cli.py test --sim modelsim --std $(VHDL_STD) $(TB_ARGS)

docker-build:
	$(PYTHON) scripts/docker_build.py --tag $(IMAGE)

docker-test: docker-build
	docker run --rm -v "$(CURDIR):/work" -w /work $(IMAGE) make test-ghdl TB="$(TB)" VHDL_STD="$(VHDL_STD)"

clean:
	rm -rf build
