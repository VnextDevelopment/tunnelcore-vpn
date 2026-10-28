#!/usr/bin/env python3
"""Reject Android 15-unsupported Window bar color method references in final DEX.

Scan the actual minified APK or AAB, not source code or raw string names:
Qt may define a method called setStatusBarColor, which is not an Android API
call. The DEX method-id table identifies the method owner precisely.
"""
import argparse
import struct
import sys
import zipfile
from pathlib import Path

WINDOW = "Landroid/view/Window;"
FORBIDDEN = frozenset(("setStatusBarColor", "setNavigationBarColor"))


def _u32(data, pos):
    return struct.unpack_from("<I", data, pos)[0]


def _skip_uleb128(data, pos):
    for _ in range(5):
        byte = data[pos]
        pos += 1
        if not byte & 0x80:
            return pos
    raise ValueError("Invalid DEX string length")


def find_unsupported_window_calls(dex):
    if len(dex) < 112 or not dex.startswith(b"dex\\n") or dex[7] != 0:
        raise ValueError("Invalid Android DEX")
    string_count, string_off = _u32(dex, 0x38), _u32(dex, 0x3C)
    type_count, type_off = _u32(dex, 0x40), _u32(dex, 0x44)
    method_count, method_off = _u32(dex, 0x58), _u32(dex, 0x5C)
    for count, offset, stride in ((string_count, string_off, 4),
                                  (type_count, type_off, 4),
                                  (method_count, method_off, 8)):
        if offset + count * stride > len(dex):
            raise ValueError("Invalid DEX ID table")

    cache = {}

    def name(index):
        if not 0 <= index < string_count:
            raise ValueError("Invalid DEX string index")
        if index not in cache:
            pos = _skip_uleb128(dex, _u32(dex, string_off + index * 4))
            cache[index] = dex[pos:dex.index(0, pos)].decode("utf-8", errors="replace")
        return cache[index]

    bad = set()
    for i in range(method_count):
        class_idx, _proto_idx, method_name_idx = struct.unpack_from(
            "<HHI", dex, method_off + i * 8)
        if class_idx >= type_count:
            raise ValueError("Invalid DEX type index")
        if name(_u32(dex, type_off + class_idx * 4)) == WINDOW:
            method_name = name(method_name_idx)
            if method_name in FORBIDDEN:
                bad.add(method_name)
    return sorted(bad)


def check_package(path):
    inspected = 0
    problems = []
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if not (name.endswith(".dex") and
                    (name.startswith("base/dex/") or "/" not in name)):
                continue
            inspected += 1
            for method in find_unsupported_window_calls(archive.read(name)):
                problems.append(f"{name}: {WINDOW}->{method}(I)V")
    if not inspected:
        raise RuntimeError(f"No DEX files in {path}")
    if problems:
        raise RuntimeError("Google Play Android 15 unsupported APIs still in DEX:\\n" +
                           "\\n".join(problems))
    print(f"Validated {inspected} DEX files in {path}: no deprecated Window bar setters")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path, help="Signed .apk or .aab")
    args = parser.parse_args()
    try:
        check_package(args.package)
    except (OSError, ValueError, RuntimeError, zipfile.BadZipFile) as exc:
        print(f"::error::{exc}", file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
