#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Small simulator runner for the VHDL Ethernet benches."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"

SOURCES = [
    "src/common/ether_protocol_types.vhd",
    "src/common/prbs_lfsr.vhd",
    "src/io/io_sdr_in.vhd",
    "src/io/io_sdr_out.vhd",
    "src/io/io_sdr_in_diff.vhd",
    "src/io/io_sdr_out_diff.vhd",
    "src/io/io_ddr_in.vhd",
    "src/io/io_ddr_out.vhd",
    "src/io/io_ddr_in_diff.vhd",
    "src/io/io_ddr_out_diff.vhd",
    "src/axis/sync_reset_pipe.vhd",
    "src/axis/priority_picker.vhd",
    "src/axis/round_robin_arbiter.vhd",
    "src/axis/axis_byte_adapter.vhd",
    "src/axis/axis_byte_register.vhd",
    "src/axis/axis_byte_fifo.vhd",
    "src/axis/axis_byte_async_fifo.vhd",
    "src/axis/axis_byte_async_fifo_adapter.vhd",
    "src/axis/axis_byte_fifo_adapter.vhd",
    "src/axis/axis_byte_pipeline.vhd",
    "src/axis/axis_byte_pipeline_fifo.vhd",
    "src/axis/axis_byte_srl_register.vhd",
    "src/axis/axis_byte_srl_fifo.vhd",
    "src/axis/axis_byte_broadcast2.vhd",
    "src/axis/axis_byte_mux2.vhd",
    "src/axis/axis_byte_demux2.vhd",
    "src/axis/axis_byte_crosspoint2.vhd",
    "src/axis/axis_byte_switch2.vhd",
    "src/axis/axis_byte_tap.vhd",
    "src/axis/axis_byte_frame_join2.vhd",
    "src/axis/axis_byte_cobs_encoder.vhd",
    "src/axis/axis_byte_cobs_decoder.vhd",
    "src/axis/axis_to_ll_byte_bridge.vhd",
    "src/axis/ll_to_axis_byte_bridge.vhd",
    "src/axis/axis_frame_length_meter.vhd",
    "src/axis/axis_frame_length_adjuster.vhd",
    "src/axis/axis_frame_length_adjust_fifo.vhd",
    "src/axis/axis_byte_rate_limit.vhd",
    "src/axis/axis_byte_stat_counter.vhd",
    "src/stream/ether_fcs_calc.vhd",
    "src/stream/ether_fcs_append.vhd",
    "src/stream/ether_fcs_strip.vhd",
    "src/mac/ether_gmii_tx_path.vhd",
    "src/mac/ether_gmii_rx_path.vhd",
    "src/mac/ether_mac_gmii_1g.vhd",
    "src/mac/ether_mac_1g_fifo.vhd",
    "src/mac/ether_mac_1g_gmii_fifo.vhd",
    "src/mac/mac_pause_frame_tx.vhd",
    "src/mac/mac_pause_frame_rx.vhd",
    "src/mac/mac_control_tx.vhd",
    "src/mac/mac_control_rx.vhd",
    "src/layers/ether_frame_tx.vhd",
    "src/layers/ether_frame_rx.vhd",
    "src/layers/ether_arp_payload_tx.vhd",
    "src/layers/ether_arp_payload_rx.vhd",
    "src/layers/ether_arp_stack.vhd",
    "src/layers/ether_arp_cache.vhd",
    "src/layers/ether_ipv4_tx.vhd",
    "src/layers/ether_ipv4_rx.vhd",
    "src/layers/ether_ipv4_stack.vhd",
    "src/layers/ether_udp_tx.vhd",
    "src/layers/ether_udp_rx.vhd",
    "src/layers/ether_udp_checksum_gen.vhd",
    "src/layers/ether_udp_stack.vhd",
    "src/layers/ether_udp_ipv4_complete.vhd",
]

TESTS = [
    "tb_axis_eth_fcs",
    "tb_fcs",
    "tb_eth_frame",
    "tb_arp",
    "tb_ipv4_udp",
    "tb_throughput",
    "tb_eth_mac_1g",
    "tb_eth_mac_1g_fifo",
    "tb_axis_helpers",
    "tb_arp_cache",
    "tb_axis_routing",
    "tb_axis_service",
    "tb_udp_checksum_lfsr",
    "tb_frame_adjust",
    "tb_axis_expansion",
    "tb_axis_cobs",
    "tb_io_cells",
    "tb_protocol_wrappers",
    "tb_axis_async_fifo",
]

TEST_FILES = [f"tests/{name}.vhd" for name in TESTS]


def run(cmd: list[str], cwd: Path = ROOT) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=cwd, check=True)


def require(tool: str) -> str:
    path = shutil.which(tool)
    if not path:
        raise SystemExit(f"error: '{tool}' was not found on PATH")
    return path


def ghdl(tests: list[str], standard: str) -> None:
    require("ghdl")
    workdir = BUILD / "ghdl"
    shutil.rmtree(workdir, ignore_errors=True)
    workdir.mkdir(parents=True, exist_ok=True)

    files = SOURCES + TEST_FILES
    std_flag = f"--std={standard}"
    run(["ghdl", "-a", std_flag, f"--workdir={workdir}", *files])
    for test in tests:
        run(["ghdl", "-e", std_flag, f"--workdir={workdir}", test])
        run(["ghdl", "-r", std_flag, f"--workdir={workdir}", test, "--assert-level=error"])


def modelsim(tests: list[str], standard: str) -> None:
    require("vlib")
    require("vcom")
    require("vsim")
    workdir = BUILD / "modelsim"
    workdir.mkdir(parents=True, exist_ok=True)
    vcom_flag = "-2019" if standard == "19" else "-2008"

    shutil.rmtree(workdir / "work", ignore_errors=True)
    run(["vlib", "work"], cwd=workdir)
    for file_name in SOURCES + TEST_FILES:
        run(["vcom", vcom_flag, str(ROOT / file_name)], cwd=workdir)
    for test in tests:
        run(["vsim", "-c", test, "-do", "run -all; quit -f"], cwd=workdir)


def list_items() -> None:
    print("Sources:")
    for item in SOURCES:
        print(f"  {item}")
    print("\nTestbenches:")
    for item in TESTS:
        print(f"  {item}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["list", "test"])
    parser.add_argument("--sim", choices=["auto", "ghdl", "modelsim"], default="auto")
    parser.add_argument("--std", choices=["08", "19"], default="08", help="VHDL standard revision")
    parser.add_argument("--tb", action="append", choices=TESTS, help="Run one testbench; may be repeated")
    args = parser.parse_args()

    if args.command == "list":
        list_items()
        return 0

    tests = args.tb or TESTS
    sim = args.sim
    if sim == "auto":
        sim = "ghdl" if shutil.which("ghdl") else "modelsim" if shutil.which("vsim") else "ghdl"

    if sim == "ghdl":
        ghdl(tests, args.std)
    else:
        modelsim(tests, args.std)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.returncode)
