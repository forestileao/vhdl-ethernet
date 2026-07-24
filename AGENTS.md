# AGENTS.md

Guidance for coding agents working in `vhdl-ethernet`.  This is a VHDL-2008
Ethernet building-block library with self-checking simulation benches.  Read
this file before making changes; the conventions below are easy to miss and
are enforced by lint and the test suite.

## What this repository is

- 100 synthesizable/simulation `.vhd` sources under `src/`, grouped into small
  protocol layers.
- 27 self-checking VHDL testbenches under `tests/`.
- A single Makefile plus a small Python runner (`scripts/vhdl_cli.py`) as the
  whole command surface.  There is no vendor project file and no external
  Python dependency; the scripts use only the standard library.

## Directory layout

```text
src/common/   Shared types and protocol helper functions (2 files)
src/io/       Simulation-friendly SDR/DDR single-ended and differential IO cells (8)
src/axis/     Generic 8/64-bit AXI byte-stream helpers, FIFOs, arbiters, COBS (32)
src/stream/   Ethernet FCS insert/strip/calc streaming blocks, 8- and 64-bit (5)
src/mac/      GMII 1G and XGMII 10G MAC paths, PHY interface shims, pause frames (18)
src/phy/      10G BASE-R block encode/decode and PHY / MAC+PHY wrappers (4)
src/ptp/      PTP timestamp counter, CDC, perout, capture, tag, tod, time dist (9)
src/layers/   Ethernet frame, ARP, IPv4, and UDP packet layers, 8- and 64-bit (22)
tests/        Self-checking VHDL testbenches (tb_*.vhd)
scripts/      CLI runner, lint, and Docker build used by the Makefile
```

Protocol stack, bottom to top: IO cells (`src/io`) and PHY interface shims plus
BASE-R (`src/phy`, parts of `src/mac`) sit at the wire; MAC paths (`src/mac`)
handle GMII/XGMII framing, preamble, FCS, and IFG; FCS streaming primitives
live in `src/stream`; the AXI byte-stream fabric is in `src/axis`; and the
Ethernet/ARP/IPv4/UDP packet logic lives in `src/layers`.  PTP timestamping
support is isolated in `src/ptp`.

## Build and test commands

Run everything from the repo root.  The Makefile forwards to
`scripts/vhdl_cli.py`.

```sh
make list           # List all sources (compile order) and testbenches
make lint           # Repo-local lint checks (stdlib Python only)
make test           # GHDL if present, else ModelSim/Questa fallback
make test-ghdl      # Force GHDL
make test-modelsim  # Force ModelSim/Questa CLI (vlib/vcom/vsim)
make verify         # lint then the simulator suite
make docker-build   # Build the local GHDL test image
make docker-test    # Build the image then run the suite in Docker (GHDL)
make clean          # Remove build/ products
```

Run a subset of benches with `TB` (space-separated testbench entity names):

```sh
make test-modelsim TB="tb_fcs tb_arp"
make docker-test   TB="tb_ipv4_udp"
```

Select the VHDL standard with `VHDL_STD` (default `08`):

```sh
make docker-test VHDL_STD=19
```

## Simulator reality on this machine

- `make test` uses `--sim auto`: it prefers GHDL when it is on `PATH` and falls
  back to ModelSim/Questa (`vsim`).
- This machine currently has ModelSim/Questa but not GHDL, so `make test` and
  `make test-modelsim` are what run locally, while GHDL runs through Docker.
- Docker is the most repeatable GHDL path; `make docker-test` is the canonical
  GHDL check.
- VHDL-2008 (`VHDL_STD=08`) is the supported baseline and must stay clean.
  VHDL-2019 (`VHDL_STD=19`) is only partially supported: the Docker image ships
  GHDL 5.0.1 from Debian stable, which passes the 2008 suite but lacks the
  IEEE library directory needed for `--std=19`.  Do not rely on VHDL-2019.

## Registration is manual, not auto-discovered

Sources and benches are listed explicitly in `scripts/vhdl_cli.py`.  Nothing is
globbed, so new files are ignored until registered.

- New `.vhd` source: add its path to the `SOURCES` list in dependency compile
  order.  Both GHDL and ModelSim analyze `SOURCES` top to bottom, so a file
  must appear after everything it depends on (e.g. after
  `src/common/ether_protocol_types.vhd`).
- New testbench: name the file `tests/tb_<name>.vhd`, add `"tb_<name>"` to the
  `TESTS` list, and make the entity name match.  `--tb` choices are validated
  against `TESTS`, so an unregistered bench cannot be selected.

Benches are self-checking: they use VHDL `assert` statements and stop
automatically on success.  GHDL runs them with `--assert-level=error`, so any
failing assertion fails the run.  Keep new benches in the same style—assert
expected values and finish cleanly.

## Style and lint expectations

`scripts/lint.py` and `.editorconfig` enforce these; `make lint` must pass
before committing:

- UTF-8 encoding and LF line endings (`.gitattributes` normalizes `*.vhd`,
  `*.py`, `*.md`, and `Makefile`).
- Final newline at end of file.
- No trailing whitespace.
- 4-space indentation; no tabs anywhere except `Makefile` (which requires tabs).
- SPDX header `SPDX-License-Identifier: MIT` within the first 5 lines of every
  `.vhd` and `.py` file, and of `Makefile` and `Dockerfile`.
- Python files must byte-compile (`py_compile`).

Before committing, run `make lint` and the test suite (`make docker-test` for
GHDL, or `make test-modelsim` where ModelSim is available) and make sure both
pass.  Keep changes focused and consistent with the existing block style.

## Notes worth knowing

- `udp_tx` leaves its checksum field at zero for the simple streaming IPv4
  path; pair it with `udp_checksum_gen` when a non-zero UDP checksum is needed.
- The MAC integration wrappers (`ether_mac_gmii_1g`, `eth_mac_10g`,
  `eth_mac_phy_10g`) are synchronous, simulation-oriented compositions; vendor
  IO register wrappers remain a board-level choice.
- Build products land in `build/` and are removed by `make clean`; do not
  commit them (they are git-ignored).
