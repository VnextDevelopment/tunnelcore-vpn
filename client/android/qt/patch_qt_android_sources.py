#!/usr/bin/env python3
"""Stage Qt 6.10 Android Java sources with the Android 15+ edge-to-edge fixes.

Never modify the installed Qt SDK: androiddeployqt points the Gradle :qt project
at Qt's Java source tree. Stage a patched copy for compilation instead.
This patch intentionally targets Qt 6.10.1 and fails on unexpected Qt changes.
"""
from pathlib import Path
import shutil
import sys

QT_DISPLAY_MANAGER = Path("org/qtproject/qt/android/QtDisplayManager.java")


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
    # Android 15 deprecates direct system-bar colors. Legacy Android obtains
    # the proper colors from the app theme; 15+ draws behind transparent bars.
    # Remove the entire block (including getters) rather than obscuring API
    # calls, so the compiled QtDisplayManager does not reference them.
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


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: patch_qt_android_sources.py <qtAndroidDir/src> <output-dir>")
    source_dir = Path(sys.argv[1]).resolve()
    output_dir = Path(sys.argv[2]).resolve()
    original_file = source_dir / QT_DISPLAY_MANAGER
    if not original_file.is_file():
        raise SystemExit(f"Qt Android Java source not found: {original_file}")
    # Validate before replacing an existing generated directory.
    patched = patch_display_manager(original_file.read_text(encoding="utf-8"))
    if output_dir.is_dir():
        shutil.rmtree(output_dir)
    shutil.copytree(source_dir, output_dir)
    (output_dir / QT_DISPLAY_MANAGER).write_text(patched, encoding="utf-8")
    print(f"Qt Android Edge-to-Edge patch staged in {output_dir}")


if __name__ == "__main__":
    main()
