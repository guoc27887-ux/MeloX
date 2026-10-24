from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from release_telegram_caption import (
    CAPTION_LIMIT,
    fit_caption,
    read_localized_details,
    telegram_length,
)


class ReleaseTelegramCaptionTests(unittest.TestCase):
    def test_reads_bilingual_platform_notes(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "ReleaseNotes.md"
            path.write_text(
                "## 简体中文\n\n- 中文更新\n## English\n\n- English update\n",
                encoding="utf-8",
            )

            self.assertEqual(
                read_localized_details(path),
                {
                    "zh-Hans": ["- 中文更新"],
                    "en": ["- English update"],
                },
            )

    def test_fits_bilingual_caption_within_telegram_limit(self) -> None:
        details = {
            "zh-Hans": [f"- 第 {index} 条更新，包含较长的功能说明" for index in range(30)],
            "en": [
                f"- Update {index} with a deliberately long feature description"
                for index in range(30)
            ],
        }
        caption = fit_caption(
            "MeloX macOS",
            "v1.0.0",
            details,
            {
                "zh-Hans": "安装前请阅读说明。",
                "en": "Read the installation instructions first.",
            },
            {
                "zh-Hans": "官网提供已公证版本。",
                "en": "Notarized builds are available from the website.",
            },
            "https://example.com/release",
            "https://example.com",
        )

        self.assertLessEqual(telegram_length(caption), CAPTION_LIMIT)
        self.assertIn("更新内容 / What's new", caption)
        self.assertIn("另有", caption)
        self.assertIn("and", caption)


if __name__ == "__main__":
    unittest.main()
