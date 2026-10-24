#!/usr/bin/env python3

"""Parse the bilingual platform sections in MeloX's release notes."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys


PLATFORM_HEADINGS = {
    "ios": "iOS + Apple Watch",
    "macos": "macOS",
}
LOCALE_HEADINGS = {
    "zh-Hans": "简体中文",
    "en": "English",
}
DOCUMENT_TITLE = "MeloX Release Notes / MeloX 更新日志"
HEADING_PATTERN = re.compile(r"^(?P<level>#{1,6})\s+(?P<title>.+?)\s*$")

LocalizedEntries = dict[str, list[str]]
ReleaseSections = dict[str, LocalizedEntries]


def empty_sections() -> ReleaseSections:
    return {
        platform: {locale: [] for locale in LOCALE_HEADINGS}
        for platform in PLATFORM_HEADINGS
    }


def platform_has_entries(entries: LocalizedEntries) -> bool:
    return any(entries.values())


def parse_release_notes(path: Path) -> ReleaseSections:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise ValueError(
            f"Unable to read release notes / 无法读取更新日志 {path}: {error}"
        ) from error

    sections = empty_sections()
    expected_platform_by_heading = {
        heading: platform for platform, heading in PLATFORM_HEADINGS.items()
    }
    expected_locale_by_heading = {
        heading: locale for locale, heading in LOCALE_HEADINGS.items()
    }
    seen_platforms: set[str] = set()
    seen_locales: dict[str, set[str]] = {
        platform: set() for platform in PLATFORM_HEADINGS
    }
    current_platform: str | None = None
    current_locale: str | None = None
    saw_title = False

    for line_number, line in enumerate(lines, start=1):
        stripped_line = line.strip()
        if not stripped_line:
            continue

        heading_match = HEADING_PATTERN.fullmatch(stripped_line)
        if heading_match:
            level = len(heading_match.group("level"))
            heading = heading_match.group("title")
            if level == 1 and heading == DOCUMENT_TITLE and not saw_title:
                saw_title = True
                current_platform = None
                current_locale = None
                continue
            if level == 2 and heading in expected_platform_by_heading:
                platform = expected_platform_by_heading[heading]
                if platform in seen_platforms:
                    raise ValueError(
                        f"Duplicate platform heading / 重复平台标题 at line "
                        f"{line_number}: {heading}"
                    )
                seen_platforms.add(platform)
                current_platform = platform
                current_locale = None
                continue
            if (
                level == 3
                and current_platform is not None
                and heading in expected_locale_by_heading
            ):
                locale = expected_locale_by_heading[heading]
                if locale in seen_locales[current_platform]:
                    raise ValueError(
                        f"Duplicate language heading / 重复语言标题 at line "
                        f"{line_number}: {heading}"
                    )
                seen_locales[current_platform].add(locale)
                current_locale = locale
                continue
            raise ValueError(
                f"Unknown heading / 未知标题 at line {line_number}: {stripped_line}"
            )

        if not saw_title:
            raise ValueError(
                f"Release notes must start with / 更新日志必须以 "
                f"# {DOCUMENT_TITLE} 开头"
            )
        if current_platform is None or current_locale is None:
            raise ValueError(
                f"Entry has no platform/language section / 条目不属于平台或语言区块 "
                f"at line {line_number}"
            )
        if not stripped_line.startswith("- ") or not stripped_line[2:].strip():
            raise ValueError(
                f"Each entry must be one Markdown list item / 每条更新必须是单条 "
                f"Markdown 列表项 at line {line_number}"
            )
        sections[current_platform][current_locale].append(stripped_line)

    if not saw_title:
        raise ValueError(
            f"Release notes must start with / 更新日志必须以 "
            f"# {DOCUMENT_TITLE} 开头"
        )

    missing_platforms = [
        heading
        for platform, heading in PLATFORM_HEADINGS.items()
        if platform not in seen_platforms
    ]
    if missing_platforms:
        raise ValueError(
            "Missing platform sections / 缺少平台区块: "
            + ", ".join(missing_platforms)
        )

    for platform, platform_heading in PLATFORM_HEADINGS.items():
        missing_locales = [
            heading
            for locale, heading in LOCALE_HEADINGS.items()
            if locale not in seen_locales[platform]
        ]
        if missing_locales:
            raise ValueError(
                f"{platform_heading} is missing language sections / 缺少语言区块: "
                + ", ".join(missing_locales)
            )
        entry_counts = {
            locale: len(sections[platform][locale]) for locale in LOCALE_HEADINGS
        }
        if len(set(entry_counts.values())) != 1:
            counts = ", ".join(
                f"{LOCALE_HEADINGS[locale]}={count}"
                for locale, count in entry_counts.items()
            )
            raise ValueError(
                f"{platform_heading} translations must have matching entry counts / "
                f"中英文条目数必须一致: {counts}"
            )

    if not any(platform_has_entries(entries) for entries in sections.values()):
        raise ValueError(
            "iOS + Apple Watch and macOS release notes cannot both be empty / "
            "两个平台的更新日志不能同时为空"
        )

    return sections


def write_platform_notes(
    entries: LocalizedEntries,
    output: Path,
    *,
    allow_empty: bool = False,
) -> None:
    if not platform_has_entries(entries) and not allow_empty:
        raise ValueError(
            "Cannot generate notes for a platform with no changes / "
            "不能为没有更新内容的平台生成更新日志"
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    blocks: list[str] = []
    for locale, heading in LOCALE_HEADINGS.items():
        if blocks:
            blocks.append("")
        blocks.append(f"## {heading}")
        blocks.extend(["", *entries[locale]])
    markdown = "\n".join(blocks).rstrip()
    output.write_text(f"{markdown}\n", encoding="utf-8")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--notes", required=True, type=Path)
    parser.add_argument("--platform", choices=PLATFORM_HEADINGS)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--github-output", type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    if (arguments.platform is None) != (arguments.output is None):
        print(
            "--platform and --output must be used together / "
            "--platform 与 --output 必须一起使用",
            file=sys.stderr,
        )
        return 2
    if arguments.output is None and arguments.github_output is None:
        print(
            "Provide --output or --github-output / 必须提供其中一个输出参数",
            file=sys.stderr,
        )
        return 2

    try:
        sections = parse_release_notes(arguments.notes)
        if arguments.platform is not None:
            write_platform_notes(
                sections[arguments.platform],
                arguments.output,
            )
        if arguments.github_output is not None:
            targets = [
                platform
                for platform, entries in sections.items()
                if platform_has_entries(entries)
            ]
            with arguments.github_output.open("a", encoding="utf-8") as output:
                output.write(f"platforms={json.dumps(targets, separators=(',', ':'))}\n")
                for platform in PLATFORM_HEADINGS:
                    has_entries = platform_has_entries(sections[platform])
                    output.write(
                        f"has_{platform}={'true' if has_entries else 'false'}\n"
                    )
    except ValueError as error:
        print(
            f"Failed to parse release notes / 解析更新日志失败: {error}",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
