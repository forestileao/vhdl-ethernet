#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the Docker image while hiding Docker's legacy-builder deprecation noise."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

LEGACY_WARNING_PREFIXES = (
    "DEPRECATED: The legacy builder is deprecated",
    "            Install the buildx component",
    "            https://docs.docker.com/go/buildx/",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()

    cmd = ["docker", "build", "-t", args.tag, "."]
    print("+", " ".join(cmd), flush=True)
    result = subprocess.run(
        cmd,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )

    for line in result.stdout.splitlines():
        if line.startswith(LEGACY_WARNING_PREFIXES):
            continue
        if line:
            print(line)

    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
