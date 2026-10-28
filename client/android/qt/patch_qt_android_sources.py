#!/usr/bin/env python3
"""Rebuild Qt 6.10.1's QtDisplayManager class inside a copy of Qt6Android.jar.

Qt's SDK ships QtDisplayManager compiled in Qt6Android.jar, NOT in
qtAndroidDir/src (which only contains QtActivity/Service/Application wrappers).
Keep the original SDK jar untouched and expose the patched copy through :qt.
The exact original Qt 6.10.1 Java source is vendored beside this script.
SPDX-License-Identifier: LGPL-3.0-only
"""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

QT_CLASS = "org/qtproject/qt/android/QtDisplayManager.class"
QT_SOURCE = "org/qtproject/qt/android/QtDisplayManager.java"


def replace_once(source: str, old: str, new: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"Unexpected QtDisplayManager source: expected one match, found {count}: {old!r}")
    return source.replace(old, new, 1)


def patch_display_manager(source: str) -> str:
    # Qt 6.10 toggles decor fits back to true on Android 15 after the app
    # enables edge-to-edge. Keep old-platform behavior intact.
    source = replace_once(
        source,
        "                window.setDecorFitsSystemWindows(true);",
        """                // Android 15+ must remain edge-to-edge, even when Qt
                // switches from fullscreen to its regular window mode.
                window.setDecorFitsSystemWindows(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM);""",
    )
    source = replace_once(
        source,
        "                cutoutMode = LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;",
        """                cutoutMode = Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM
                        ? LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                        : LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;""",
    )
    source = replace_once(
        source,
        "                cutoutMode = LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT;",
        """                cutoutMode = Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM
                        ? LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                        : LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT;""",
    )
    # Remove direct calls to Android 15-deprecated bar color setters (including
    # reads) from the compiled Qt class. Android < 15 uses the app theme.
    start_marker = "        if (!isFullScreen && !edgeToEdgeEnabled(m_activity)) {"
    end_marker = "\n\n        decorView.post(() -> decorView.requestApplyInsets());"
    if source.count(start_marker) != 1 or source.count(end_marker) != 1:
        raise RuntimeError("Unexpected QtDisplayManager system bars block")
    start = source.index(start_marker)
    end = source.index(end_marker, start)
    source = (source[:start]
              + "        // Bar backgrounds come from the app theme (API < 35) or QML (API 35+)."
              + source[end:])
    source = replace_once(
        source,
        "        window.setStatusBarColor(color);",
        "        // Legacy system bar colors are supplied by the application theme.",
    )
    source = replace_once(
        source,
        "        window.setNavigationBarColor(color);",
        "        // Legacy system bar colors are supplied by the application theme.",
    )
    for call in ("window.setStatusBarColor(", "window.setNavigationBarColor(",
                 "window.getStatusBarColor(", "window.getNavigationBarColor("):
        if call in source:
            raise RuntimeError(f"Unsupported system bar access remains: {call}")
    return source


def patch_jar(qt_jar: Path, android_jar: Path, source_file: Path, output: Path) -> None:
    for path in (qt_jar, android_jar, source_file):
        if not path.is_file():
            raise FileNotFoundError(f"Required Android build input missing: {path}")
    patched = patch_display_manager(source_file.read_text(encoding="utf-8"))
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="qt-display-patch-") as tmp:
        tmp = Path(tmp)
        java_file = tmp / QT_SOURCE
        java_file.parent.mkdir(parents=True)
        java_file.write_text(patched, encoding="utf-8")
        classes = tmp / "classes"
        classes.mkdir()
        subprocess.run(
            ["javac", "-source", "8", "-target", "8",
             "-classpath", os.pathsep.join((str(qt_jar), str(android_jar))),
             "-d", str(classes), str(java_file)],
            check=True,
        )
        patched_class = (classes / QT_CLASS).read_bytes()
        # DEX verification: the patched class must not reference the removed
        # android.view.Window methods even via a constant-pool methodref.
        for forbidden in (b"setStatusBarColor", b"setNavigationBarColor"):
            # Qt's named helper methods retain these names, but Android's
            # deprecated Window methodrefs must be absent in javap output.
            result = subprocess.run(
                ["javap", "-verbose", "-classpath", str(classes),
                 "org.qtproject.qt.android.QtDisplayManager"],
                text=True, capture_output=True, check=True,
            )
            if any("android/view/Window." + forbidden.decode() in line
                   for line in result.stdout.splitlines()):
                raise RuntimeError(f"Deprecated Window call in generated Java class: {forbidden!r}")
        seen = 0
        with zipfile.ZipFile(qt_jar, "r") as original, zipfile.ZipFile(output, "w") as patched_jar:
            for info in original.infolist():
                if info.filename == QT_CLASS:
                    seen += 1
                    patched_jar.writestr(info, patched_class)
                else:
                    patched_jar.writestr(info, original.read(info.filename))
        if seen != 1:
            output.unlink(missing_ok=True)
            raise RuntimeError(f"Qt6Android.jar must contain exactly one {QT_CLASS}, found {seen}")
    print(f"Built patched Qt Android jar at {output} (other Qt classes untouched)")


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("Usage: patch_qt_android_sources.py <Qt6Android.jar> <android.jar> <output.jar>")
    qt_jar = Path(sys.argv[1]).resolve()
    android_jar = Path(sys.argv[2]).resolve()
    output = Path(sys.argv[3]).resolve()
    source_file = Path(__file__).parent / "qt-6.10.1/QtDisplayManager.java"
    patch_jar(qt_jar, android_jar, source_file, output)


if __name__ == "__main__":
    main()
