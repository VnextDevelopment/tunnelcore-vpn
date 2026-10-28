"""Google Play release notes must use Play Console locale tags, not Qt locales."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
NOTES = ROOT / "docs/google-play-release-notes"
SUPPORTED = (
    "en-US", "ru-RU", "tr-TR", "zh-CN", "uk", "fa-IR",
    "ar", "my-MM", "ur", "hi-IN", "es-ES", "ko-KR", "fr-FR",
)

class GooglePlayReleaseNoteLocalesTest(unittest.TestCase):
    def test_console_locale_tags_and_content(self):
        content = (NOTES / "google-play-console.txt").read_text(encoding="utf-8")
        blocks = re.findall(r"<([\w-]+)>\n([\s\S]*?)\n</\1>", content)
        self.assertEqual([locale for locale, _ in blocks], list(SUPPORTED))
        self.assertEqual(content.strip(), "\n\n".join(
            f"<{locale}>\n{body}\n</{locale}>" for locale, body in blocks
        ))
        for locale, body in blocks:
            with self.subTest(locale=locale):
                self.assertTrue(body.strip())
                self.assertLessEqual(len(body), 500)
                self.assertEqual(
                    (NOTES / f"{locale}.txt").read_text(encoding="utf-8").strip(),
                    body.strip(),
                )

    def test_invalid_qt_locale_variants_are_not_present(self):
        content = (NOTES / "google-play-console.txt").read_text(encoding="utf-8")
        for old in ("uk-UA", "ur-PK", "ar-EG"):
            self.assertNotIn(f"<{old}>", content)

if __name__ == "__main__":
    unittest.main()
