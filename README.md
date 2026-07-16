# vhdl-ethernet

VHDL-2008 Ethernet building blocks with self-checking simulation benches.

This repository is organized as a VHDL-native project.  The source is split
into small protocol layers under `src/`, tests live under `tests/`, and the
command surface is a single Makefile plus a tiny Python runner.

## Current Scope

- 8-bit AXI-style byte streams with `tvalid`, `tready`, `tlast`, and `tuser`.
- Ethernet FCS insertion and checking.
- 64-bit AXI-stream Ethernet FCS insertion and checking with `tkeep`.
- Standalone Ethernet FCS calculation.
- Ethernet frame header transmit and receive.
- Basic 1G GMII MAC path: AXI-stream to/from GMII with preamble, FCS, and IFG.
- 10G XGMII MAC paths with 64-bit and 32-bit XGMII buses, start/terminate
  control, FCS, and IFG handling.
- 10G BASE-R block encoder/decoder, PHY wrapper, and MAC+PHY wrapper for
  block-boundary integration tests.
- FIFO-wrapped 1G GMII MAC variants for easier stream integration.
- MAC control pause-frame transmit and receive helpers.
- ARP packet transmit and receive for Ethernet/IPv4.
- ARP, IPv4, UDP, and UDP-over-IPv4 stack wrapper components.
- 64-bit IPv4/UDP transmit, receive, checksum, stack, and complete wrapper
  variants with `tkeep` lane handling.
- PTP timestamp counter, CDC sampler, periodic output, frame timestamp capture,
  timestamp extraction, tag tracking, time-distribution helpers, and
  time-of-day splitting.
- Small direct-mapped ARP cache for IPv4-to-MAC lookups.
- 2-port AXI byte-stream mux/demux, tap, FIFO, broadcast, pipeline, rate-limit,
  statistics, frame-length, frame-length-adjust, and dual-clock async FIFO
  helper blocks.
- Buffered 2-port AXI byte-stream RAM-style switch.
- AXI byte-stream COBS encoder and decoder for delimiter-safe framing.
- Generic reset synchronizer, priority picker, round-robin arbiter, and PRBS
  LFSR utility.
- Simulation-friendly SDR/DDR single-ended and differential IO cells.
- Simulation-friendly MII, GMII, and RGMII PHY interface shims.
- IPv4 transmit and receive for fixed 20-byte headers.
- UDP transmit, receive, and checksum generation over IPv4 streams.

## Layout

```text
src/common/   Shared types and protocol helper functions
src/io/       Small simulation IO cells
src/axis/     Generic AXI byte-stream helpers and arbiters
src/stream/   Ethernet FCS streaming blocks
src/mac/      GMII/MAC-facing blocks
src/phy/      10G BASE-R block and PHY wrappers
src/ptp/      PTP timestamping and time-distribution helpers
src/layers/   Ethernet, ARP, IPv4, and UDP packet layers
tests/        Self-checking VHDL testbenches
scripts/      CLI runner used by the Makefile
```

## Commands

```sh
make list
make lint
make test
make test-ghdl
make test-modelsim
make docker-build
make docker-test
```

Use `TB` to run a subset:

```sh
make test-modelsim TB="tb_fcs tb_arp"
make docker-test TB="tb_ipv4_udp"
```

Use `VHDL_STD=19` to try the latest official VHDL language revision with a
simulator that supports it:

```sh
make docker-test VHDL_STD=19
```

`make test` prefers GHDL when available and falls back to ModelSim/Questa CLI.
This machine currently has ModelSim available but not GHDL, so Docker is the
most repeatable GHDL path.

The default remains `VHDL_STD=08` because IEEE 1076-2019 is the latest official
VHDL revision, but open-source simulator support for VHDL-2019 is still partial.
Keeping the project VHDL-2008-clean gives the broadest 2026 simulator coverage
while leaving the VHDL-2019 switch available for newer commercial/open-source
toolchains.  The Docker image currently installs GHDL 5.0.1 from Debian stable;
that package passes the VHDL-2008 suite but does not ship the VHDL-2019 IEEE
library directory needed for `--std=19`.

## Testbenches

- `tb_fcs`: streams a frame through FCS insert and then FCS check.
- `tb_fcs64`: streams a wide `tkeep` frame through 64-bit FCS insert/check.
- `tb_axis_eth_fcs`: checks the standalone Ethernet FCS calculator against a
  known CRC-32 value.
- `tb_eth_frame`: sends an Ethernet header and payload through TX/RX blocks.
- `tb_arp`: builds and parses an ARP request payload.
- `tb_arp_cache`: writes, reads, misses, and clears the ARP cache.
- `tb_ipv4_udp`: sends UDP payload through UDP TX, IPv4 TX/RX, and UDP RX.
- `tb_ipv4_udp64`: checks the 64-bit UDP-over-IPv4 wrapper with uneven
  `tkeep`.
- `tb_throughput`: checks the FCS insert/check stream path against a cycle
  budget for a 512-byte frame.
- `tb_eth_mac_1g`: loops a frame through `eth_mac_1g` GMII TX/RX.
- `tb_eth_mac_10g`: loops a wide frame through the 10G XGMII MAC path.
- `tb_eth_mac_10g32`: loops a wide stream frame through a 32-bit XGMII MAC
  path.
- `tb_baser_phy_10g`: loops a frame through the 10G MAC+BASE-R block wrapper.
- `tb_ptp_family`: checks the PTP clock, CDC, periodic output, timestamp
  capture/extract, tag tracker, time-distribution helpers, and time-of-day
  splitter.
- `tb_axis_helpers`: checks the stream register, FIFO, broadcast, reset
  synchronizer, priority picker, and round-robin arbiter.
- `tb_axis_routing`: checks mux, demux, tap, and frame-length helpers.
- `tb_axis_service`: checks pipeline, SRL-style wrappers, rate limiter, and
  stream statistics.
- `tb_udp_checksum_lfsr`: checks UDP checksum generation and the PRBS LFSR.
- `tb_frame_adjust`: checks padding/truncation and status reporting for
  frame-length adjustment.
- `tb_axis_expansion`: checks adapters, frame join, crosspoint, switch, and
  AXI/LocalLink byte bridges.
- `tb_axis_ram_switch`: checks the buffered two-output byte-stream switch.
- `tb_axis_cobs`: checks COBS encode/decode round trips with embedded zeros.
- `tb_eth_mac_1g_fifo`: loops a frame through the FIFO-wrapped GMII MAC.
- `tb_io_cells`: checks SDR/DDR single-ended and differential IO cells.
- `tb_phy_interfaces`: checks MII, GMII, and RGMII PHY interface shims.
- `tb_protocol_wrappers`: checks ARP/IPv4/UDP stack wrappers and MAC control
  pause-frame helpers.
- `tb_axis_async_fifo`: checks a dual-clock AXI byte-stream async FIFO adapter.

All benches use VHDL assertions and stop automatically on success.

## Notes

`udp_tx` keeps its checksum field at zero for the simple streaming IPv4 path.
Use `udp_checksum_gen` beside it when an application requires a non-zero UDP
checksum computed over the pseudo-header and payload.

The `ether_mac_gmii_1g`, `eth_mac_10g`, and `eth_mac_phy_10g` blocks are
synchronous integration wrappers intended for simulation and portable RTL
composition.  FIFO-wrapped stream variants, standalone async stream FIFOs,
pause-frame helpers, 10G XGMII/BASE-R wrappers, and PTP timestamp helpers are
included; vendor-specific IO register wrappers remain a board-level integration
choice.

## License

This project is licensed under the MIT License.  See [LICENSE](LICENSE).
