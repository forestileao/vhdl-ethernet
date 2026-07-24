# AGENTS.md

Guidance for coding agents working in the vhdl-ethernet repository.  This file
is the authoritative quick reference; when it disagrees with reality, trust the
`Makefile` and `scripts/` and update this file to match.

## Project Purpose

vhdl-ethernet is a library of VHDL-2008 Ethernet building blocks with
self-checking simulation benches.  Sources are small, composable protocol
layers under `src/`; every block is exercised by a testbench under `tests/`.
The command surface is a single `Makefile` plus a small Python runner in
`scripts/`.

## Directory Layout

```text
src/common/   Shared types and protocol helper functions (eth_types_pkg)
src/io/       Small simulation IO cells (SDR/DDR, single-ended/differential)
src/axis/     Generic AXI byte-stream helpers and arbiters
src/stream/   Ethernet FCS streaming blocks
src/mac/      GMII/MAC-facing blocks and PHY interface shims
src/phy/      10G BASE-R block and PHY wrappers
src/ptp/      PTP timestamping and time-distribution helpers
src/layers/   Ethernet, ARP, IPv4, and UDP packet layers
tests/        Self-checking VHDL testbenches (tb_*.vhd)
scripts/      Python CLI runner, lint, and Docker build used by the Makefile
```

Synthesizable/simulation RTL lives under `src/`.  Verification code lives under
`tests/`.  Do not mix the two: a testbench never ships in `src/`, and design
logic never hides inside a bench.

## Primary Commands

```sh
make list           # List registered source files and testbenches
make lint           # Run repo-local lint checks (pure Python stdlib)
make test           # Run tests: GHDL if present, else ModelSim/Questa CLI
make test-ghdl      # Force GHDL
make test-modelsim  # Force ModelSim/Questa CLI
make verify         # lint + test
make docker-build   # Build the local GHDL test image
make docker-test    # Build the image and run the suite inside Docker
make clean          # Remove the build/ directory
```

Run a subset of benches with `TB=` (space-separated testbench names):

```sh
make test-modelsim TB="tb_fcs tb_arp"
make docker-test   TB="tb_ipv4_udp"
```

Select the VHDL revision with `VHDL_STD=` (default `08`, `19` is the only other
accepted value):

```sh
make test          VHDL_STD=08
make docker-test   VHDL_STD=19
```

## Simulator Situation

- `make test` (sim `auto`) prefers GHDL and falls back to ModelSim/Questa when
  GHDL is not on `PATH`.
- This project's default dev machine typically has ModelSim/Questa but not
  GHDL installed locally.  For a repeatable GHDL run use Docker:
  `make docker-test` builds `debian:stable-slim` + GHDL and runs `make
  test-ghdl` inside the container against a bind-mounted checkout.
- GHDL runs benches with `--assert-level=error`; ModelSim runs `run -all;
  quit -f`.  Benches must therefore stop themselves and fail via assertions.

## VHDL-2008 Default Rationale

The default is `VHDL_STD=08` even though IEEE 1076-2019 is the latest official
revision, because open-source simulator support for VHDL-2019 is still partial.
Keeping every source and bench VHDL-2008-clean gives the broadest 2026
simulator coverage.  The Docker image ships GHDL 5.0.1 from Debian stable,
which passes the VHDL-2008 suite but does not include the VHDL-2019 IEEE
library needed for `--std=19`; use a supporting simulator for `VHDL_STD=19`.

## Coding Conventions

- Target VHDL-2008.  Keep sources and benches VHDL-2008-clean so the full
  matrix (`make test-ghdl`, `make test-modelsim`, Docker) keeps passing.  Only
  reach for VHDL-2019 features behind the explicit `VHDL_STD=19` path.
- Every `.vhd` and `.py` file must begin with an SPDX header in the first five
  lines: `-- SPDX-License-Identifier: MIT` for VHDL, `# SPDX-License-Identifier:
  MIT` for Python.  `Makefile` and `Dockerfile` need it too.  `make lint`
  enforces this.
- Formatting (from `.editorconfig` and enforced by `make lint`): UTF-8, LF line
  endings, a final newline, no trailing whitespace, and 4-space indentation.
  Tabs are only allowed in the `Makefile`.
- Shared protocol types and helpers live in `src/common/ether_protocol_types.vhd`
  as package `eth_types_pkg` (for example `byte_t`).  Reuse them instead of
  redefining local aliases.
- Keep blocks small and composable, matching the existing per-layer style.

## Testing Conventions

- Every new source block needs a self-checking testbench under `tests/`.  Model
  it on an existing bench (for example `tests/tb_fcs.vhd`): drive stimulus,
  compare against expected values with `assert`, and end with
  `std.env.stop`/`finish` on success.  No manual waveform inspection.
- Registration is manual and order-sensitive.  When you add files you MUST
  update `scripts/vhdl_cli.py`:
  - Add new design files to the `SOURCES` list in dependency/compile order
    (packages and dependencies before the blocks that use them).
  - Add new bench names (without the `.vhd` suffix) to the `TESTS` list; the
    runner derives `tests/<name>.vhd` from it and the `--tb` choices come from
    this list.
- Keep `README.md`'s "Testbenches" section in sync when you add or rename a
  bench so docs and code stay consistent.

## Definition of Done

Before considering a change complete:

1. `make lint` passes.
2. The test suite passes (`make test`, or `make docker-test` for a repeatable
   GHDL run when GHDL is not installed locally).  Run the full suite, not just
   the bench you touched.
3. New blocks ship with a self-checking bench registered in
   `scripts/vhdl_cli.py`, and documentation (`README.md`, this file) stays
   consistent with the code.

This file intentionally avoids duplicating README/Makefile detail beyond what
an agent needs to build, test, and extend the project safely.
