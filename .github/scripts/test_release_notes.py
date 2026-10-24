from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from release_notes import parse_release_notes, write_platform_notes


class ReleaseNotesTests(unittest.TestCase):
    def parse(self, content: str) -> dict[str, dict[str, list[str]]]:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "RELEASE_NOTES.md"
            path.write_text(content, encoding="utf-8")
            return parse_release_notes(path)

    def test_parses_both_platforms_and_languages(self) -> None:
        sections = self.parse(
            "# MeloX Release Notes / MeloX 更新日志\n\n"
            "## iOS + Apple Watch\n\n"
            "### 简体中文\n\n"
            "- iOS 更新\n\n"
            "### English\n\n"
            "- iOS update\n\n"
            "## macOS\n\n"
            "### 简体中文\n\n"
            "- macOS 更新\n\n"
            "### English\n\n"
            "- macOS update\n"
        )

        self.assertEqual(sections["ios"]["zh-Hans"], ["- iOS 更新"])
        self.assertEqual(sections["ios"]["en"], ["- iOS update"])
        self.assertEqual(sections["macos"]["zh-Hans"], ["- macOS 更新"])
        self.assertEqual(sections["macos"]["en"], ["- macOS update"])

    def test_allows_one_platform_to_be_empty_in_both_languages(self) -> None:
        sections = self.parse(
            "# MeloX Release Notes / MeloX 更新日志\n\n"
            "## iOS + Apple Watch\n\n"
            "### 简体中文\n\n"
            "- iOS 更新\n\n"
            "### English\n\n"
            "- iOS update\n\n"
            "## macOS\n\n"
            "### 简体中文\n\n"
            "### English\n"
        )

        self.assertEqual(sections["macos"]["zh-Hans"], [])
        self.assertEqual(sections["macos"]["en"], [])

    def test_rejects_missing_platform_heading(self) -> None:
        with self.assertRaisesRegex(ValueError, "Missing platform sections"):
            self.parse(
                "# MeloX Release Notes / MeloX 更新日志\n\n"
                "## iOS + Apple Watch\n\n"
                "### 简体中文\n\n"
                "- iOS 更新\n\n"
                "### English\n\n"
                "- iOS update\n"
            )

    def test_rejects_missing_language_heading(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing language sections"):
            self.parse(
                "# MeloX Release Notes / MeloX 更新日志\n\n"
                "## iOS + Apple Watch\n\n"
                "### 简体中文\n\n"
                "- iOS 更新\n\n"
                "## macOS\n\n"
                "### 简体中文\n\n"
                "### English\n"
            )

    def test_rejects_mismatched_translation_counts(self) -> None:
        with self.assertRaisesRegex(ValueError, "matching entry counts"):
            self.parse(
                "# MeloX Release Notes / MeloX 更新日志\n\n"
                "## iOS + Apple Watch\n\n"
                "### 简体中文\n\n"
                "- 第一条\n"
                "- 第二条\n\n"
                "### English\n\n"
                "- First\n\n"
                "## macOS\n\n"
                "### 简体中文\n\n"
                "### English\n"
            )

    def test_writes_selected_platform_in_both_languages(self) -> None:
        with TemporaryDirectory() as directory:
            output = Path(directory) / "ReleaseNotes.md"
            write_platform_notes(
                {
                    "zh-Hans": ["- macOS 更新"],
                    "en": ["- macOS update"],
                },
                output,
            )
            self.assertEqual(
                output.read_text(encoding="utf-8"),
                "## 简体中文\n\n- macOS 更新\n\n## English\n\n- macOS update\n",
            )


if __name__ == "__main__":
    unittest.main()
