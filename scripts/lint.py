#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Repository lint checks that only depend on Python's standard library."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

TEXT_SUFFIXES = {
    ".vhd",
    ".py",
    ".md",
    ".txt",
    ".yml",
    ".yaml",
}

SPDX_REQUIRED = {
    "Dockerfile",
    "Makefile",
}


def tracked_text_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if ".git" in path.parts or "build" in path.parts or "__pycache__" in path.parts:
            continue
        if not path.is_file():
            continue
        if path.name in SPDX_REQUIRED or path.suffix in TEXT_SUFFIXES:
            files.append(path)
    return sorted(files)


def check_text(files: list[Path]) -> list[str]:
    errors: list[str] = []
    for path in files:
        data = path.read_bytes()
        rel = path.relative_to(ROOT)

        if data and not data.endswith(b"\n"):
            errors.append(f"{rel}: missing final newline")

        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            errors.append(f"{rel}: not valid UTF-8")
            continue

        for lineno, line in enumerate(text.splitlines(), start=1):
            if line.rstrip(" \t") != line:
                errors.append(f"{rel}:{lineno}: trailing whitespace")
            if path.name != "Makefile" and "\t" in line:
                errors.append(f"{rel}:{lineno}: tab outside Makefile")
    return errors


def check_spdx(files: list[Path]) -> list[str]:
    errors: list[str] = []
    for path in files:
        rel = path.relative_to(ROOT)
        required = path.suffix in {".vhd", ".py"} or path.name in SPDX_REQUIRED
        if not required:
            continue
        head = "\n".join(path.read_text(encoding="utf-8").splitlines()[:5])
        if "SPDX-License-Identifier: MIT" not in head:
            errors.append(f"{rel}: missing SPDX-License-Identifier: MIT")
    return errors


def check_python(files: list[Path]) -> list[str]:
    errors: list[str] = []
    for path in files:
        if path.suffix != ".py":
            continue
        import subprocess

        result = subprocess.run(
            [sys.executable, "-m", "py_compile", str(path)],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            errors.append(result.stdout.strip())
    return errors


def main() -> int:
    files = tracked_text_files()
    errors: list[str] = []
    errors.extend(check_text(files))
    errors.extend(check_spdx(files))
    errors.extend(check_python(files))

    if errors:
        print("lint failed:")
        for error in errors:
            print(f"  {error}")
        return 1

    print(f"lint passed ({len(files)} text files checked)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
