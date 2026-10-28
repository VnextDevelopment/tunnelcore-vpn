"""Tests for bytecode-level Android 15 deprecated Window API gate."""
import importlib.util
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/check_android_window_apis.py"
spec = importlib.util.spec_from_file_location("dex_window_api_check", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def fixture(owner, method):
    values = (owner, method)
    data = bytearray(112)
    data[:8] = b"dex\\n035\\x00"
    strings_at = len(data)
    data.extend(b"\\x00" * 8)
    types_at = len(data)
    data.extend(struct.pack("<I", 0))
    methods_at = len(data)
    data.extend(struct.pack("<HHI", 0, 0, 1))
    for i, value in enumerate(values):
        offset = len(data)
        struct.pack_into("<I", data, strings_at + 4 * i, offset)
        encoded = value.encode("ascii")
        assert len(encoded) < 128
        data.extend(bytes((len(encoded),)) + encoded + b"\\x00")
    for pos, value in ((0x38, 2), (0x3C, strings_at), (0x40, 1),
                       (0x44, types_at), (0x58, 1), (0x5C, methods_at)):
        struct.pack_into("<I", data, pos, value)
    return bytes(data)


class DeprecatedWindowApiDexTest(unittest.TestCase):
    def test_detects_deprecated_android_window_methods(self):
        for method in module.FORBIDDEN:
            with self.subTest(method=method):
                self.assertEqual(
                    module.find_unsupported_window_calls(fixture(module.WINDOW, method)),
                    [method]
                )

    def test_does_not_flag_qt_methods_of_same_name(self):
        self.assertEqual(module.find_unsupported_window_calls(
            fixture("Lorg/qtproject/qt/android/QtDisplayManager;", "setStatusBarColor")
        ), [])

    def test_finds_calls_in_apk_and_aab(self):
        for file_name, dex_name in (("test.apk", "classes.dex"),
                                    ("test.aab", "base/dex/classes.dex")):
            with self.subTest(file_name=file_name), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / file_name
                with zipfile.ZipFile(path, "w") as archive:
                    archive.writestr(dex_name, fixture(module.WINDOW, "setNavigationBarColor"))
                with self.assertRaisesRegex(RuntimeError, "setNavigationBarColor"):
                    module.check_package(path)

    def test_rejects_missing_dex(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.aab"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("base/manifest/AndroidManifest.xml", b"abc")
            with self.assertRaisesRegex(RuntimeError, "No DEX"):
                module.check_package(path)


if __name__ == "__main__":
    unittest.main()
