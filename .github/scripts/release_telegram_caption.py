#!/usr/bin/env python3

"""Build a bilingual Telegram release caption within the Bot API limit."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


CAPTION_LIMIT = 1024
LANGUAGE_HEADINGS = {
    "## 简体中文": "zh-Hans",
    "## English": "en",
}


def telegram_length(text: str) -> int:
    return len(text.encode("utf-16-le")) // 2


def read_localized_details(path: Path) -> dict[str, list[str]]:
    details = {locale: [] for locale in LANGUAGE_HEADINGS.values()}
    current_locale: str | None = None
    seen_locales: set[str] = set()
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        stripped_line = line.strip()
        if not stripped_line:
            continue
        if stripped_line in LANGUAGE_HEADINGS:
            current_locale = LANGUAGE_HEADINGS[stripped_line]
            if current_locale in seen_locales:
                raise ValueError(
                    f"Duplicate language section / 重复语言区块 at line {line_number}"
                )
            seen_locales.add(current_locale)
            continue
        if current_locale is None or not stripped_line.startswith("- "):
            raise ValueError(
                f"Invalid localized release-note line / 双语更新日志格式错误 "
                f"at line {line_number}: {stripped_line}"
            )
        details[current_locale].append(stripped_line)

    missing_locales = set(details) - seen_locales
    if missing_locales:
        raise ValueError(
            "Missing language sections / 缺少语言区块: "
            + ", ".join(sorted(missing_locales))
        )
    if len(details["zh-Hans"]) != len(details["en"]):
        raise ValueError(
            "Chinese and English entry counts differ / 中英文更新条目数不一致"
        )
    return details


def compose_caption(
    project: str,
    version: str,
    details: dict[str, list[str]],
    install_notes: dict[str, str],
    distribution_notes: dict[str, str],
    release_url: str,
    website_url: str,
) -> str:
    lines = [f"{project} {version} 更新 / Update"]
    if details["zh-Hans"]:
        lines.extend(
            [
                "",
                "更新内容 / What's new",
                "中文：",
                *details["zh-Hans"],
                "English:",
                *details["en"],
            ]
        )
    if install_notes["zh-Hans"] or install_notes["en"]:
        lines.extend(
            [
                "",
                "安装提示 / Installation",
                install_notes["zh-Hans"],
                install_notes["en"],
            ]
        )
    if distribution_notes["zh-Hans"] or distribution_notes["en"]:
        lines.extend(
            [
                "",
                distribution_notes["zh-Hans"],
                distribution_notes["en"],
            ]
        )
    lines.extend(
        [
            "",
            f"GitHub Release / 发版：{release_url}",
            f"Website / 官网：{website_url}",
            "欢迎了解并分享 MeloX！ / Discover MeloX and share it with friends!",
        ]
    )
    return "\n".join(line for line in lines if line is not None)


def fit_caption(
    project: str,
    version: str,
    details: dict[str, list[str]],
    install_notes: dict[str, str],
    distribution_notes: dict[str, str],
    release_url: str,
    website_url: str,
) -> str:
    full_caption = compose_caption(
        project,
        version,
        details,
        install_notes,
        distribution_notes,
        release_url,
        website_url,
    )
    if telegram_length(full_caption) <= CAPTION_LIMIT:
        return full_caption

    visible_count = 0
    detail_count = len(details["zh-Hans"])
    for candidate_count in range(1, detail_count + 1):
        omitted_count = detail_count - candidate_count
        candidate_details = {
            locale: entries[:candidate_count]
            for locale, entries in details.items()
        }
        if omitted_count:
            candidate_details["zh-Hans"].append(
                f"- ……另有 {omitted_count} 条，详见 GitHub Release"
            )
            candidate_details["en"].append(
                f"- …and {omitted_count} more; see the GitHub Release"
            )
        candidate = compose_caption(
            project,
            version,
            candidate_details,
            install_notes,
            distribution_notes,
            release_url,
            website_url,
        )
        if telegram_length(candidate) > CAPTION_LIMIT:
            break
        visible_count = candidate_count

    omitted_count = detail_count - visible_count
    visible_details = {
        locale: entries[:visible_count]
        for locale, entries in details.items()
    }
    if omitted_count:
        visible_details["zh-Hans"].append(
            f"- ……另有 {omitted_count} 条，详见 GitHub Release"
        )
        visible_details["en"].append(
            f"- …and {omitted_count} more; see the GitHub Release"
        )
    caption = compose_caption(
        project,
        version,
        visible_details,
        install_notes,
        distribution_notes,
        release_url,
        website_url,
    )
    if telegram_length(caption) > CAPTION_LIMIT:
        raise ValueError(
            "Telegram caption exceeds 1,024 characters even without details / "
            "Telegram Caption 即使省略更新条目仍超过 1,024 字符"
        )
    return caption


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--details-file", required=True, type=Path)
    parser.add_argument("--install-note-zh", default="")
    parser.add_argument("--install-note-en", default="")
    parser.add_argument("--distribution-note-zh", default="")
    parser.add_argument("--distribution-note-en", default="")
    parser.add_argument("--release-url", required=True)
    parser.add_argument("--website-url", required=True)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        details = read_localized_details(arguments.details_file)
        caption = fit_caption(
            arguments.project,
            arguments.version,
            details,
            {
                "zh-Hans": arguments.install_note_zh.strip(),
                "en": arguments.install_note_en.strip(),
            },
            {
                "zh-Hans": arguments.distribution_note_zh.strip(),
                "en": arguments.distribution_note_en.strip(),
            },
            arguments.release_url,
            arguments.website_url,
        )
    except (OSError, ValueError) as error:
        print(
            f"Failed to generate Telegram caption / 生成 Telegram Caption 失败: {error}",
            file=sys.stderr,
        )
        return 1

    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(f"{caption}\n", encoding="utf-8")
    print(caption)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
