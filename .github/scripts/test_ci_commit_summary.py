import unittest

from ci_commit_summary import CAPTION_LIMIT, format_summary, telegram_length


class CICommitSummaryTests(unittest.TestCase):
    def test_summary_is_bilingual_and_within_telegram_limit(self) -> None:
        commits = [
            (
                f"{index:040x}",
                f"Commit subject {index} with a deliberately long description",
                "Contributor",
            )
            for index in range(30)
        ]

        summary = format_summary(
            commits,
            "1" * 40,
            100,
            "2" * 40,
            101,
            "youshen2/MeloX",
            "https://example.com/actions/101",
            "https://melox.luoxe.cn/",
            "MeloX macOS",
        )

        self.assertLessEqual(telegram_length(summary), CAPTION_LIMIT)
        self.assertIn("CI build completed / CI 构建完成", summary)
        self.assertIn("Website / 官网", summary)
        self.assertIn("and", summary)
        self.assertIn("另有", summary)


if __name__ == "__main__":
    unittest.main()
