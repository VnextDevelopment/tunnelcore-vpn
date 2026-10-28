"""Regression coverage for Android 15+ Edge-to-Edge and Qt 6.10 patches."""
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "client/android/qt/patch_qt_android_sources.py"
spec = spec_from_file_location("patch_qt_android_sources", SCRIPT)
module = module_from_spec(spec)
spec.loader.exec_module(module)

QT_610_FRAGMENT = """
class QtDisplayManager {
    void setSystemUiVisibility(boolean isFullScreen) {
        if (m_isFullScreen || m_expandedToCutout) {
                window.setDecorFitsSystemWindows(false);
                cutoutMode = LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        } else {
                window.setDecorFitsSystemWindows(true);
                cutoutMode = LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT;
        }

        if (!isFullScreen && !edgeToEdgeEnabled(m_activity)) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS
                        | WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION);
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
            if (m_expandedToCutout) {
                window.setStatusBarColor(Color.TRANSPARENT);
                window.setNavigationBarColor(Color.TRANSPARENT);
            } else {
                int statusBarColor = window.getStatusBarColor();
                int navigationBarColor = window.getNavigationBarColor();
                window.setStatusBarColor(statusBarColor);
                window.setNavigationBarColor(navigationBarColor);
            }
        }

        decorView.post(() -> decorView.requestApplyInsets());
    }

    static void setStatusBarColor(Window window, int color) {
        window.setStatusBarColor(color);
    }

    static void setNavigationBarColor(Window window, int color) {
        window.setNavigationBarColor(color);
    }
}
"""


class AndroidEdgeToEdgeTest(unittest.TestCase):
    def test_qt_java_patch_removes_deprecated_color_calls(self):
        patched = module.patch_display_manager(QT_610_FRAGMENT)
        for expression in (
            "window.setStatusBarColor(", "window.setNavigationBarColor(",
            "window.getStatusBarColor(", "window.getNavigationBarColor(",
        ):
            self.assertNotIn(expression, patched)
        self.assertIn("LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS", patched)
        self.assertIn("Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM", patched)
        self.assertIn("decorView.requestApplyInsets()", patched)

    def test_qt_patch_fails_closed_on_unexpected_version(self):
        with self.assertRaises(RuntimeError):
            module.patch_display_manager(QT_610_FRAGMENT.replace(
                "window.setDecorFitsSystemWindows(true);",
                "window.setDecorFitsSystemWindows(false);",
            ))

    def test_activity_uses_window_edge_to_edge_and_passive_ime(self):
        activity = (ROOT / "client/android/src/org/amnezia/vpn/AmneziaActivity.kt").read_text()
        versions = (ROOT / "client/android/gradle/libs.versions.toml").read_text()
        qt_gradle = (ROOT / "client/android/qt/build.gradle.kts").read_text()
        self.assertIn("applyEdgeToEdgeWithoutColorSetters()", activity)
        self.assertIn("SOFT_INPUT_ADJUST_RESIZE", activity)
        self.assertIn("setupPassiveImeInsetsObserver()", activity)
        self.assertIn("WindowCompat.setDecorFitsSystemWindows(window, false)", activity)
        self.assertNotIn("WindowCompat.enableEdgeToEdge(window)", activity)
        self.assertIn("window.isStatusBarContrastEnforced = false", activity)
        self.assertNotIn("window.navigationBarColor =", activity)
        self.assertNotIn("statusBarColor =", activity)
        self.assertIn('androidx-core = "1.17.0"', versions)
        self.assertIn("qt-6.10.1/QtDisplayManager.java", qt_gradle)
        self.assertIn('"exclude" to listOf("Qt6Android.jar")', qt_gradle)
        self.assertIn('java.setSrcDirs(listOf("$qtAndroidDir/src"))', qt_gradle)
        self.assertIn("patchQtAndroidJar", qt_gradle)
        self.assertIn("api(files(patchedQtJar).builtBy(patchQtAndroidJar))", qt_gradle)

    def test_androidx_edge_to_edge_build_toolchain_is_compatible(self):
        """Core 1.17 requires AGP 8.9.1+, and AGP 8.10 needs Gradle 8.11.1."""
        versions = (ROOT / "client/android/gradle/libs.versions.toml").read_text()
        settings = (ROOT / "client/android/settings.gradle.kts").read_text()
        wrapper = (ROOT / "client/android/gradle/wrapper/gradle-wrapper.properties").read_text()
        self.assertIn('androidx-core = "1.17.0"', versions)
        self.assertIn('agp = "8.10.1"', versions)
        self.assertIn('id("com.android.settings") version "8.10.1"', settings)
        self.assertIn('gradle-8.11.1-bin.zip', wrapper)

    def test_android_14_bar_colors_are_declarative(self):
        theme = (ROOT / "client/android/res/values-v34/styles.xml").read_text()
        self.assertIn('<item name="android:statusBarColor">@android:color/transparent</item>', theme)
        self.assertIn('<item name="android:navigationBarColor">@android:color/transparent</item>', theme)
        self.assertIn('name="android:windowSplashScreenAnimatedIcon"', theme)

    def test_legacy_theme_colors_are_defined(self):
        for path in (
            "client/android/res/values/styles.xml",
            "client/android/res/values-v31/styles.xml",
        ):
            theme = (ROOT / path).read_text()
            self.assertIn('name="android:statusBarColor"', theme)
            self.assertIn('name="android:navigationBarColor"', theme)
            self.assertIn('name="android:windowLayoutInDisplayCutoutMode">always', theme)


if __name__ == "__main__":
    unittest.main()
