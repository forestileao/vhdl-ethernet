# AGENTS.md

Guide for coding agents working in `vhdl-ethernet`. This is a VHDL-2008
Ethernet building-block library: ~100 `.vhd` sources under `src/`, 27
self-checking benches under `tests/`, driven by a `Makefile` plus a small
Python runner in `scripts/`. Read this before changing code; several
conventions here are not auto-enforced and are easy to miss.

## Repository layout

```text
src/common/   Shared types and protocol helper functions (ether_protocol_types, prbs_lfsr)
src/io/       Simulation-friendly SDR/DDR single-ended and differential IO cells
src/axis/     Generic AXI byte-stream helpers, FIFOs, arbiters, switches, COBS, bridges
src/stream/   Ethernet FCS streaming blocks (8-bit and 64-bit tkeep insert/strip/calc)
src/mac/      GMII 1G MAC paths, 10G XGMII MAC paths, MII/GMII/RGMII PHY shims, pause/control
src/phy/      10G BASE-R block encode/decode, PHY wrapper, MAC+PHY wrapper
src/ptp/      PTP clock, CDC sampler, perout, timestamp capture/extract, tag tracker, TOD split
src/layers/   Ethernet frame, ARP, IPv4, UDP packet layers (8-bit and 64-bit variants), ARP cache
tests/        Self-checking VHDL testbenches (tb_*.vhd)
scripts/      CLI runner (vhdl_cli.py), lint (lint.py), Docker build helper (docker_build.py)
```

The library builds bottom-up: `common` -> `ptp`/`io`/`axis` -> `stream` ->
`mac`/`phy` -> `layers`. Compile order matters (see registration below).

## Build and test commands

All commands run from the repo root via the `Makefile`:

```sh
make list            # List registered sources and testbenches
make lint            # Repo-local lint checks (stdlib Python only)
make verify          # Runs lint then the simulator suite
make test            # Auto-select GHDL, else ModelSim/Questa
make test-ghdl       # Force GHDL
make test-modelsim   # Force ModelSim/Questa CLI (vlib/vcom/vsim)
make docker-build    # Build the local GHDL image (vhdl-ethernet-ghdl)
make docker-test     # Build then run the suite inside Docker (most repeatable GHDL path)
make clean           # Remove the build/ directory
```

Run a subset with `TB` (space-separated bench names, no `.vhd`):

```sh
make test-modelsim TB="tb_fcs tb_arp"
make docker-test TB="tb_ipv4_udp"
```

Select the VHDL standard with `VHDL_STD` (default `08`):

```sh
make docker-test VHDL_STD=19
```

## Simulator reality on this machine

- `make test` prefers GHDL when it is on `PATH` and falls back to
  ModelSim/Questa; this machine has ModelSim/Questa available but not GHDL.
- Docker is the most repeatable GHDL path. The image installs GHDL from Debian
  stable; it passes the VHDL-2008 suite but does not ship the VHDL-2019 IEEE
  library needed for `--std=19`.
- VHDL-2008 is the supported baseline and gives the broadest simulator
  coverage. VHDL-2019 (`VHDL_STD=19`) is only partially supported and needs a
  toolchain that ships the 2019 IEEE libraries.
- GHDL runs use `--assert-level=error`; benches self-check via VHDL assertions
  and stop automatically on success.

## Registering new sources and benches (required, not auto-discovered)

Files are not globbed. Edit `scripts/vhdl_cli.py` when adding files:

- New `.vhd` sources: add the path to the `SOURCES` list in dependency compile
  order (a block must appear after everything it instantiates or uses).
- New benches: add the bench name (without `tests/` or `.vhd`) to the `TESTS`
  list. `TEST_FILES` and the `--tb` choices are derived from `TESTS`.

Forgetting either step means the file is silently excluded from `make list`,
`make test`, and CI-style runs.

## Style and lint expectations

Enforced by `scripts/lint.py` and `.editorconfig`:

- UTF-8 encoding, LF line endings, a final newline on every file.
- No trailing whitespace.
- No tab characters outside `Makefile` (indent with 4 spaces).
- SPDX headers: `SPDX-License-Identifier: MIT` in the first 5 lines of every
  `.vhd` and `.py` file, and of `Makefile` and `Dockerfile`. VHDL uses a
  `-- SPDX-License-Identifier: MIT` comment; Python/Makefile/Dockerfile use
  `# SPDX-License-Identifier: MIT`.
- `lint.py` also byte-compiles every `.py` file, so Python must at least parse.

Run `make lint` and the relevant test target before committing. Do not
introduce guidance or code that contradicts the README, Makefile, scripts, or
`.editorconfig`.

## Conventions for new blocks and benches

- Use 8-bit AXI-style byte streams (`tvalid`, `tready`, `tlast`, `tuser`) for
  narrow paths, or 64-bit streams with `tkeep` for wide paths, matching the
  existing `*64` variants.
- Keep blocks synchronous and simulation/portable-RTL friendly; vendor-specific
  IO register wrappers are left as a board-level choice.
- Add a self-checking bench under `tests/` that drives the block and asserts
  expected results, then register it in `TESTS`. Model new benches on existing
  ones (for example `tb_fcs`, `tb_arp`, `tb_ipv4_udp`).

## Writing a self-checking testbench

Benches are pure VHDL and must decide pass/fail on their own; there are no
golden logs or waveform diffs. The runner only checks the exit status, so a
bench that never asserts anything is a false pass. Follow the structure used by
`tb_fcs`, `tb_arp`, and `tb_ipv4_udp`:

- Entity is empty (`entity tb_x is end entity;`); everything lives in the
  architecture. Start the file with the SPDX comment and
  `library std; use std.env.all;` so `finish` and `stop` are visible.
- Generate a free-running clock, for example `clk <= not clk after 5 ns;`
  (a 100 MHz, 10 ns period), and assert reset for a few cycles before driving
  stimulus (`wait for 40 ns; rst <= '0';`).
- Drive inputs synchronously from a `stimulus` process using
  `wait until rising_edge(clk);`. Honor back-pressure: only advance a
  `tvalid`/`tready` beat when `tready = '1'`. Reuse the `send_frame` helper
  pattern for byte streams.
- Check outputs in a separate `scoreboard` process clocked on `rising_edge(clk)`
  that compares each accepted beat (`tvalid = '1' and tready = '1'`) against the
  expected bytes, verifies `tlast` lands on the final byte, and confirms error
  flags such as `tuser`, `bad_frame`, and `bad_fcs` behave as intended.
- Report failures with `assert <cond> report "..." severity failure;`. GHDL runs
  with `--assert-level=error`, so a `failure` (or `error`) assertion stops the
  simulation with a non-zero exit and fails the target.
- End the run deterministically: signal completion with a `done` flag, guard it
  with a bounded loop so a hang becomes a real failure
  (`assert done report "... timed out" severity failure;`), then call `finish;`
  so the simulator returns cleanly instead of running forever.
- Prefer constants and helper procedures for stimulus vectors so the intent of
  each frame is readable and easy to extend.

## Verify after every change (required)

Run these from the repo root before committing, whether you added a block,
edited RTL, or touched a bench. Skipping the final full run is the most common
way a change regresses another block.

1. Register first. If you added or renamed a `.vhd`, update `SOURCES` and/or
   `TESTS` in `scripts/vhdl_cli.py`, then confirm it appears in `make list`.
   Unregistered files never compile and never run.
2. Lint. `make lint` (stdlib Python only; enforces SPDX, encoding, whitespace,
   final newline, and byte-compiles every `.py`).
3. Iterate on the focused bench while developing:

   ```sh
   make docker-test TB="tb_your_block"       # repeatable GHDL path
   make test-modelsim TB="tb_your_block"     # this machine has ModelSim, not GHDL
   ```

   Because `SOURCES` compiles bottom-up, a change low in the stack can break a
   dependent block even when your focused bench passes.
4. Final gate: run the whole suite with no `TB` filter so every dependent bench
   recompiles against your change.

   ```sh
   make verify                 # lint + full suite via auto-selected simulator
   make docker-test            # full suite, most repeatable GHDL result
   ```

   `make verify` runs `lint` then `test`; treat a green full-suite run (not just
   the focused bench) as the definition of done. A non-zero exit means a bench
   assertion tripped or a source failed to compile: read the `+ ghdl ...` or
   `+ vcom ...` line printed just before the failure to find the offending file
   or testbench.
5. Keep VHDL-2008 (`VHDL_STD=08`, the default) green. `VHDL_STD=19` is optional
   and only works on toolchains shipping the VHDL-2019 IEEE libraries, so do not
   let a 2019-only construct break the 2008 baseline.
