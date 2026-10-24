#!/usr/bin/env python3

"""Generate metadata for the Markdown release notes bundled with MeloX."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

from release_notes import (
    PLATFORM_HEADINGS,
    parse_release_notes,
    platform_has_entries,
    write_platform_notes,
)


BUILD_PREFIX = 91
BUILD_PREFIX_SCALE = 100_000
PATCH_COMPONENT_SCALE = 100


def git(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *arguments],
        check=check,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def resolve_commit(reference: str) -> str:
    result = git(
        "rev-parse",
        "--verify",
        f"{reference}^{{commit}}",
        check=False,
    )
    if result.returncode != 0:
        raise ValueError(
            f"Unable to resolve commit or tag / 无法解析 Commit 或标签: {reference}"
        )
    return result.stdout.strip()


def is_ancestor(reference: str, current_commit: str) -> bool:
    return (
        git(
            "merge-base",
            "--is-ancestor",
            reference,
            current_commit,
            check=False,
        ).returncode
        == 0
    )


def tag_matches_platform(tag: str, platform: str) -> bool:
    is_macos_tag = tag.lower().endswith("_mac")
    return is_macos_tag if platform == "macos" else not is_macos_tag


def exact_version_tag(
    current_commit: str,
    current_reference: str,
    platform: str,
) -> str | None:
    tags = git(
        "tag",
        "--points-at",
        current_commit,
        "--list",
        "v*",
        "--sort=-version:refname",
    ).stdout.splitlines()
    tags = [tag for tag in tags if tag_matches_platform(tag, platform)]
    if not tags:
        return None

    reference_name = current_reference.removeprefix("refs/tags/")
    if reference_name in tags:
        return reference_name
    return tags[0]


def infer_previous_version_tag(
    current_commit: str,
    current_tag: str | None,
    platform: str,
) -> str | None:
    result = git(
        "tag",
        "--merged",
        current_commit,
        "--list",
        "v*",
        "--sort=-version:refname",
        check=False,
    )
    if result.returncode != 0:
        return None

    for tag in result.stdout.splitlines():
        if tag != current_tag and tag_matches_platform(tag, platform):
            return tag
    return None


def validate_tag_platform(current_reference: str, platform: str) -> None:
    reference_name = current_reference.removeprefix("refs/tags/")
    if reference_name == current_reference:
        return
    if not tag_matches_platform(reference_name, platform):
        expected_suffix = "_mac" if platform == "macos" else "no _mac suffix / 无 _mac 后缀"
        raise ValueError(
            f"Tag does not match platform / 标签与平台不匹配: {reference_name} -> "
            f"{PLATFORM_HEADINGS[platform]}; expected / 期望: {expected_suffix}"
        )


def version_label(reference: str | None) -> str | None:
    if reference is None:
        return None
    reference_name = reference.removeprefix("refs/tags/")
    if reference_name.lower().endswith("_mac"):
        reference_name = reference_name[:-4]
    if len(reference_name) > 1 and reference_name[0].lower() == "v":
        return reference_name[1:]
    return reference_name


def release_version(build_number: str) -> str:
    if not build_number.isascii() or not build_number.isdecimal():
        raise ValueError("Build number must contain digits only / 构建号必须是纯数字")

    encoded_version = int(build_number)
    prefix, version_digits = divmod(encoded_version, BUILD_PREFIX_SCALE)
    if prefix != BUILD_PREFIX:
        raise ValueError(
            "Build number must start with the fixed 91 prefix / "
            "构建号必须以固定前缀 91 开头"
        )

    major, remainder = divmod(version_digits, 10_000)
    minor, patch = divmod(remainder, PATCH_COMPONENT_SCALE)
    return f"{major}.{minor}.{patch}"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--current-ref", default="HEAD")
    parser.add_argument("--previous-ref")
    parser.add_argument("--platform", required=True, choices=PLATFORM_HEADINGS)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--notes", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--markdown-output", required=True, type=Path)
    parser.add_argument("--allow-empty", action="store_true")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()

    try:
        validate_tag_platform(arguments.current_ref, arguments.platform)
        version = release_version(arguments.build_number)
        current_commit = resolve_commit(arguments.current_ref)
        current_tag = exact_version_tag(
            current_commit,
            arguments.current_ref,
            arguments.platform,
        )
        previous_reference = arguments.previous_ref or infer_previous_version_tag(
            current_commit,
            current_tag,
            arguments.platform,
        )

        if previous_reference is not None:
            if not tag_matches_platform(previous_reference, arguments.platform):
                raise ValueError(
                    f"Release-note baseline does not match the platform / "
                    f"更新日志基线与当前平台不一致: {previous_reference}"
                )
            resolve_commit(previous_reference)
            if not is_ancestor(previous_reference, current_commit):
                raise ValueError(
                    f"Release-note baseline is not an ancestor of the current commit / "
                    f"更新日志基线不是当前 Commit 的祖先: {previous_reference}"
                )

        entries = parse_release_notes(arguments.notes)[arguments.platform]
        if not platform_has_entries(entries) and not arguments.allow_empty:
            raise ValueError(
                f"{PLATFORM_HEADINGS[arguments.platform]} release notes cannot be empty / "
                "更新日志不能为空"
            )
    except (subprocess.CalledProcessError, ValueError) as error:
        print(
            f"Failed to generate release notes / 生成更新日志失败: {error}",
            file=sys.stderr,
        )
        return 1

    payload = {
        "schemaVersion": 3,
        "platform": arguments.platform,
        "version": version,
        "sourceRevision": current_commit,
        "currentRef": current_tag or arguments.current_ref,
        "previousRef": previous_reference,
        "previousVersion": version_label(previous_reference),
        "localizedEntries": {
            locale: [entry.removeprefix("- ").strip() for entry in localized_entries]
            for locale, localized_entries in entries.items()
        },
    }

    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    temporary_output = arguments.output.with_suffix(
        f"{arguments.output.suffix}.tmp"
    )
    temporary_output.write_text(
        f"{json.dumps(payload, ensure_ascii=False, indent=2)}\n",
        encoding="utf-8",
    )
    temporary_output.replace(arguments.output)
    write_platform_notes(
        entries,
        arguments.markdown_output,
        allow_empty=arguments.allow_empty,
    )

    range_description = (
        f"{previous_reference}..{current_tag or current_commit[:7]}"
        if previous_reference is not None
        else "no previous release baseline / 无可用的历史版本基线"
    )
    entry_count = len(entries["zh-Hans"])
    print(
        f"Generated / 已生成 MeloX {payload['version']} "
        f"{PLATFORM_HEADINGS[arguments.platform]} release notes / 更新日志: "
        f"{range_description}; {entry_count} translated entries / 双语条目 "
        f"from {arguments.notes}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
