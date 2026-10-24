#!/usr/bin/env python3
"""Build, Developer ID sign, notarize, and staple the MeloX macOS DMG.

The tool intentionally keeps GitHub's unsigned build separate from the locally
notarized cloud-drive artifact. It has no third-party Python dependencies.
"""

from __future__ import annotations

import argparse
import ast
import json
import os
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Optional, Sequence


TOOL_DIRECTORY = Path(__file__).resolve().parent
PROJECT_ROOT = TOOL_DIRECTORY.parents[1]
BUILD_DIRECTORY = PROJECT_ROOT / "build"
BUILD_SCRIPT = PROJECT_ROOT / "build_macos_dmg.sh"
DEFAULT_APP_PATHS = {
    "arm64": BUILD_DIRECTORY
    / "DerivedData-macOS-arm64/Build/Products/Release/MeloX Desktop.app",
    "x86_64": BUILD_DIRECTORY
    / "DerivedData-macOS-x86_64/Build/Products/Release/MeloX Desktop.app",
}
DEFAULT_OUTPUT_DIRECTORY = BUILD_DIRECTORY
ARCHITECTURE_VARIANTS = {
    "arm64": ("Apple Silicon", "Apple-Silicon"),
    "x86_64": ("Intel", "Intel"),
}
ENTITLEMENTS_PATH = PROJECT_ROOT / "MeloXDesktop/MeloXDesktop.entitlements"
TESTFLIGHT_TOOL_PATH = (
    PROJECT_ROOT / "Tools/TestFlightUploader/upload_testflight.py"
)
TESTFLIGHT_CREDENTIALS_DIRECTORY = (
    PROJECT_ROOT / "Tools/TestFlightUploader/.credentials"
)
EXPECTED_BUNDLE_ID = "azki.moye.MeloX.desktop"
APP_NAME = "MeloX Desktop"


class ReleaseError(RuntimeError):
    """A concise, user-facing release failure."""


@dataclass(frozen=True)
class SigningIdentity:
    fingerprint: str
    name: str


@dataclass(frozen=True)
class AppMetadata:
    bundle_id: str
    marketing_version: str
    build_version: str


@dataclass(frozen=True)
class NotaryAuthentication:
    description: str
    arguments: tuple[str, ...]


def print_message(message: str) -> None:
    print(message, flush=True)


def command_output(result: subprocess.CompletedProcess[bytes]) -> str:
    stdout = result.stdout.decode("utf-8", errors="replace").strip()
    stderr = result.stderr.decode("utf-8", errors="replace").strip()
    return "\n".join(part for part in (stdout, stderr) if part)


def run_command(
    command: Sequence[str],
    label: str,
    *,
    cwd: Optional[Path] = None,
    env: Optional[Mapping[str, str]] = None,
    check: bool = True,
) -> subprocess.CompletedProcess[bytes]:
    stop_event = threading.Event()
    spinner_thread: Optional[threading.Thread] = None

    if sys.stdout.isatty():
        frames = ("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")

        def animate() -> None:
            index = 0
            started_at = time.monotonic()
            while not stop_event.wait(0.1):
                elapsed = time.monotonic() - started_at
                print(
                    f"\r\033[2K{frames[index % len(frames)]} {label} ({elapsed:.1f}s)",
                    end="",
                    flush=True,
                )
                index += 1

        spinner_thread = threading.Thread(target=animate, daemon=True)
        spinner_thread.start()
    else:
        print_message(f"{label}…")

    try:
        result = subprocess.run(
            list(command),
            cwd=str(cwd) if cwd else None,
            env=dict(env) if env is not None else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    finally:
        stop_event.set()
        if spinner_thread:
            spinner_thread.join()
            print("\r\033[2K", end="", flush=True)

    if result.returncode != 0 and check:
        detail = command_output(result)
        raise ReleaseError(f"{label}失败: {detail or '命令执行失败'}")
    if result.returncode == 0:
        print_message(f"✓ {label}")
    return result


def require_tools() -> None:
    required_paths = (
        Path("/usr/bin/codesign"),
        Path("/usr/bin/ditto"),
        Path("/usr/bin/hdiutil"),
        Path("/usr/bin/lipo"),
        Path("/usr/bin/security"),
        Path("/usr/sbin/spctl"),
        Path("/usr/bin/xcrun"),
    )
    missing = [str(path) for path in required_paths if not path.is_file()]
    if missing:
        raise ReleaseError("缺少 macOS 系统工具: " + ", ".join(missing))
    for tool in ("notarytool", "stapler"):
        run_command(
            ["/usr/bin/xcrun", "--find", tool],
            f"检查 {tool}",
        )


def load_signing_identities() -> list[SigningIdentity]:
    result = subprocess.run(
        ["/usr/bin/security", "find-identity", "-v", "-p", "codesigning"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    output = command_output(result)
    identities: list[SigningIdentity] = []
    for line in output.splitlines():
        match = re.match(r'^\s*\d+\)\s+([0-9A-Fa-f]{40})\s+"(.+)"\s*$', line)
        if match and match.group(2).startswith("Developer ID Application:"):
            identities.append(
                SigningIdentity(
                    fingerprint=match.group(1).upper(),
                    name=match.group(2),
                )
            )
    return identities


def resolve_signing_identity(requested: Optional[str]) -> SigningIdentity:
    identities = load_signing_identities()
    if not identities:
        raise ReleaseError(
            "钥匙串中没有可用的 Developer ID Application 证书和私钥。"
            "App Store Connect .p8 只用于公证认证，不能代替 DMG 代码签名证书。"
        )

    if requested:
        normalized = requested.replace(":", "").upper()
        for identity in identities:
            if identity.fingerprint == normalized or identity.name == requested:
                return identity
        available = ", ".join(identity.name for identity in identities)
        raise ReleaseError(
            f"找不到指定 Developer ID 签名身份: {requested}。可用: {available}"
        )

    if len(identities) != 1:
        available = ", ".join(identity.name for identity in identities)
        raise ReleaseError(
            "检测到多个 Developer ID Application 身份，"
            f"请使用 --signing-identity 指定: {available}"
        )
    return identities[0]


def testflight_literal(name: str) -> Optional[str]:
    """Read a string default from the ignored local TestFlight tool without importing it."""
    if not TESTFLIGHT_TOOL_PATH.is_file():
        return None
    try:
        document = ast.parse(TESTFLIGHT_TOOL_PATH.read_text(encoding="utf-8"))
    except (OSError, SyntaxError, UnicodeError):
        return None
    for node in document.body:
        if not isinstance(node, ast.Assign):
            continue
        if not any(isinstance(target, ast.Name) and target.id == name for target in node.targets):
            continue
        try:
            value = ast.literal_eval(node.value)
        except (ValueError, TypeError):
            return None
        return value if isinstance(value, str) and value else None
    return None


def discover_testflight_api_key() -> Optional[Path]:
    candidates = sorted(TESTFLIGHT_CREDENTIALS_DIRECTORY.glob("AuthKey_*.p8"))
    files = [path for path in candidates if path.is_file()]
    return files[0] if len(files) == 1 else None


def infer_key_id(path: Path) -> Optional[str]:
    match = re.fullmatch(r"AuthKey_([A-Za-z0-9]+)\.p8", path.name)
    return match.group(1) if match else None


def validate_private_key(path: Path) -> None:
    if not path.is_file():
        raise ReleaseError(f"App Store Connect API 私钥不存在: {path}")
    mode = stat.S_IMODE(path.stat().st_mode)
    if mode & 0o077:
        raise ReleaseError(
            f"API 私钥权限过宽（当前 {mode:o}），请执行: chmod 600 {path}"
        )


def resolve_notary_authentication(arguments: argparse.Namespace) -> NotaryAuthentication:
    profile = arguments.notary_profile or os.environ.get("MELOX_NOTARY_KEYCHAIN_PROFILE")
    if profile:
        return NotaryAuthentication(
            description=f"钥匙串配置 {profile}",
            arguments=("--keychain-profile", profile),
        )

    raw_key_path = (
        arguments.api_key
        or os.environ.get("ASC_PRIVATE_KEY_PATH")
        or discover_testflight_api_key()
    )
    if raw_key_path is None:
        raise ReleaseError(
            "找不到 App Store Connect .p8 私钥。请使用 --api-key，"
            "或将私钥放在 TestFlightUploader/.credentials 中。"
        )
    key_path = Path(raw_key_path).expanduser().resolve()
    validate_private_key(key_path)

    key_id = (
        arguments.key_id
        or os.environ.get("ASC_KEY_ID")
        or infer_key_id(key_path)
        or testflight_literal("LOCAL_DEFAULT_KEY_ID")
    )
    issuer_id = (
        arguments.issuer_id
        or os.environ.get("ASC_ISSUER_ID")
        or testflight_literal("LOCAL_DEFAULT_ISSUER_ID")
    )
    if not key_id:
        raise ReleaseError("无法确定 API Key ID；请使用 --key-id 或 ASC_KEY_ID。")
    if not issuer_id:
        raise ReleaseError(
            "无法确定 API Issuer ID；请使用 --issuer-id 或 ASC_ISSUER_ID。"
        )
    return NotaryAuthentication(
        description=f"App Store Connect API Key {key_id}",
        arguments=(
            "--key",
            str(key_path),
            "--key-id",
            key_id,
            "--issuer",
            issuer_id,
        ),
    )


def load_app_metadata(app_path: Path) -> AppMetadata:
    info_path = app_path / "Contents/Info.plist"
    if not info_path.is_file():
        raise ReleaseError(f"App 缺少 Info.plist: {info_path}")
    try:
        with info_path.open("rb") as info_file:
            info = plistlib.load(info_file)
    except (OSError, plistlib.InvalidFileException) as error:
        raise ReleaseError(f"无法读取 {info_path}: {error}") from error

    def required_string(key: str) -> str:
        value = info.get(key)
        if value is None or not str(value).strip():
            raise ReleaseError(f"App Info.plist 缺少 {key}。")
        return str(value)

    metadata = AppMetadata(
        bundle_id=required_string("CFBundleIdentifier"),
        marketing_version=required_string("CFBundleShortVersionString"),
        build_version=required_string("CFBundleVersion"),
    )
    if metadata.bundle_id != EXPECTED_BUNDLE_ID:
        raise ReleaseError(
            f"macOS Bundle ID 不正确：期望 {EXPECTED_BUNDLE_ID}，实际 {metadata.bundle_id}"
        )
    return metadata


def build_unsigned_apps(architectures: Sequence[str]) -> dict[str, Path]:
    if not BUILD_SCRIPT.is_file():
        raise ReleaseError(f"找不到 macOS 构建脚本: {BUILD_SCRIPT}")
    environment = os.environ.copy()
    environment["MELOX_MAC_ARCHS"] = " ".join(architectures)
    run_command(
        [str(BUILD_SCRIPT)],
        "构建 macOS 分架构未签名 App",
        cwd=PROJECT_ROOT,
        env=environment,
    )
    app_paths: dict[str, Path] = {}
    for architecture in architectures:
        app_path = DEFAULT_APP_PATHS[architecture]
        if not app_path.is_dir():
            raise ReleaseError(
                f"构建成功但找不到 {ARCHITECTURE_VARIANTS[architecture][0]} App: "
                f"{app_path}"
            )
        app_paths[architecture] = app_path
    return app_paths


def validate_app_architecture(app_path: Path, architecture: str) -> None:
    info_path = app_path / "Contents/Info.plist"
    try:
        with info_path.open("rb") as info_file:
            info = plistlib.load(info_file)
    except (OSError, plistlib.InvalidFileException) as error:
        raise ReleaseError(f"无法读取 {info_path}: {error}") from error
    executable_name = info.get("CFBundleExecutable")
    if not isinstance(executable_name, str) or not executable_name:
        raise ReleaseError(f"{info_path} 缺少 CFBundleExecutable。")
    executable_path = app_path / "Contents/MacOS" / executable_name
    result = run_command(
        ["/usr/bin/lipo", "-archs", str(executable_path)],
        f"检查 {ARCHITECTURE_VARIANTS[architecture][0]} App 架构",
    )
    actual_architectures = result.stdout.decode("utf-8", errors="replace").strip()
    if actual_architectures != architecture:
        raise ReleaseError(
            f"{ARCHITECTURE_VARIANTS[architecture][0]} App 架构不正确："
            f"期望 {architecture}，实际 {actual_architectures or '未知'}"
        )


def remove_existing_signatures(root: Path) -> None:
    signature_directories = sorted(
        (path for path in root.rglob("_CodeSignature") if path.is_dir()),
        key=lambda path: len(path.parts),
        reverse=True,
    )
    for signature_directory in signature_directories:
        shutil.rmtree(signature_directory)


def discover_nested_code(app_path: Path) -> list[Path]:
    targets: set[Path] = set()
    bundle_suffixes = {".appex", ".app", ".framework", ".xpc"}
    file_suffixes = {".dylib", ".so"}
    for path in app_path.rglob("*"):
        if path.is_symlink():
            continue
        if path.is_dir() and path.suffix.lower() in bundle_suffixes:
            targets.add(path)
        elif path.is_file() and path.suffix.lower() in file_suffixes:
            targets.add(path)
    targets.discard(app_path)
    return sorted(targets, key=lambda path: (len(path.parts), str(path)), reverse=True)


def sign_app(app_path: Path, identity: SigningIdentity) -> None:
    remove_existing_signatures(app_path)
    for target in discover_nested_code(app_path):
        run_command(
            [
                "/usr/bin/codesign",
                "--force",
                "--sign",
                identity.fingerprint,
                "--timestamp",
                "--options",
                "runtime",
                str(target),
            ],
            f"签名嵌套代码 {target.name}",
        )

    run_command(
        [
            "/usr/bin/codesign",
            "--force",
            "--sign",
            identity.fingerprint,
            "--timestamp",
            "--options",
            "runtime",
            "--entitlements",
            str(ENTITLEMENTS_PATH),
            "--generate-entitlement-der",
            str(app_path),
        ],
        f"使用 Developer ID 签名 {APP_NAME}",
    )
    run_command(
        [
            "/usr/bin/codesign",
            "--verify",
            "--deep",
            "--strict",
            "--verbose=2",
            str(app_path),
        ],
        "验证 App 签名",
    )


def create_and_sign_dmg(
    signed_app: Path,
    dmg_path: Path,
    identity: SigningIdentity,
) -> None:
    staging = dmg_path.parent / "staging"
    staging.mkdir(parents=True, exist_ok=True)
    run_command(
        ["/usr/bin/ditto", "--norsrc", str(signed_app), str(staging / signed_app.name)],
        "写入 DMG 安装目录",
    )
    os.symlink("/Applications", staging / "Applications")
    run_command(
        [
            "/usr/bin/hdiutil",
            "create",
            "-volname",
            "MeloX",
            "-srcfolder",
            str(staging),
            "-ov",
            "-format",
            "UDZO",
            str(dmg_path),
        ],
        "生成 DMG",
    )
    run_command(
        [
            "/usr/bin/codesign",
            "--force",
            "--sign",
            identity.fingerprint,
            "--timestamp",
            str(dmg_path),
        ],
        "签名 DMG",
    )
    run_command(
        ["/usr/bin/codesign", "--verify", "--verbose=2", str(dmg_path)],
        "验证 DMG 签名",
    )


def parse_json_output(result: subprocess.CompletedProcess[bytes], label: str) -> Mapping[str, object]:
    raw_output = result.stdout.decode("utf-8", errors="replace").strip()
    try:
        value = json.loads(raw_output)
    except json.JSONDecodeError as error:
        raise ReleaseError(f"{label}返回了无效 JSON: {raw_output[:2000]}") from error
    if not isinstance(value, dict):
        raise ReleaseError(f"{label}返回了非对象 JSON。")
    return value


def download_notary_log(
    submission_id: str,
    authentication: NotaryAuthentication,
) -> Optional[Path]:
    BUILD_DIRECTORY.mkdir(parents=True, exist_ok=True)
    log_path = BUILD_DIRECTORY / f"notary-log-{submission_id}.json"
    result = run_command(
        [
            "/usr/bin/xcrun",
            "notarytool",
            "log",
            *authentication.arguments,
            submission_id,
            str(log_path),
        ],
        "下载公证失败日志",
        check=False,
    )
    return log_path if result.returncode == 0 and log_path.is_file() else None


def notarize_and_staple(
    dmg_path: Path,
    authentication: NotaryAuthentication,
) -> str:
    result = run_command(
        [
            "/usr/bin/xcrun",
            "notarytool",
            "submit",
            *authentication.arguments,
            "--wait",
            "--output-format",
            "json",
            str(dmg_path),
        ],
        "提交 Apple 公证并等待结果",
        check=False,
    )
    payload: Mapping[str, object] = {}
    if result.stdout.strip():
        payload = parse_json_output(result, "notarytool")
    submission_id = str(payload.get("id") or "").strip()
    status = str(payload.get("status") or "").strip()
    if result.returncode != 0 or status != "Accepted":
        log_path = download_notary_log(submission_id, authentication) if submission_id else None
        detail = command_output(result)
        log_note = f"；日志已保存至 {log_path}" if log_path else ""
        raise ReleaseError(
            f"Apple 公证未通过（状态: {status or '未知'}）{log_note}: "
            f"{detail or '无详细信息'}"
        )

    run_command(
        ["/usr/bin/xcrun", "stapler", "staple", str(dmg_path)],
        "将公证票据装订到 DMG",
    )
    run_command(
        ["/usr/bin/xcrun", "stapler", "validate", str(dmg_path)],
        "验证公证票据",
    )
    run_command(
        [
            "/usr/sbin/spctl",
            "--assess",
            "--type",
            "open",
            "--context",
            "context:primary-signature",
            "--verbose=4",
            str(dmg_path),
        ],
        "验证 Gatekeeper 接受 DMG",
    )
    return submission_id


def confirm_release(
    identity: SigningIdentity,
    authentication: NotaryAuthentication,
    output_paths: Mapping[str, Path],
    assume_yes: bool,
) -> bool:
    print_message("")
    print_message("========== macOS 签名公证信息 ==========")
    print_message(f"签名证书: {identity.name}")
    print_message(f"证书 SHA-1: {identity.fingerprint}")
    print_message(f"公证认证: {authentication.description}")
    print_message("输出:")
    for architecture, output_path in output_paths.items():
        print_message(
            f"  {ARCHITECTURE_VARIANTS[architecture][0]} ({architecture}): {output_path}"
        )
    print_message("该流程会将所选架构的 DMG 分别上传至 Apple 公证服务。")
    print_message("=========================================")
    if assume_yes:
        print_message("已通过 --yes 确认。")
        return True
    if not sys.stdin.isatty():
        raise ReleaseError("非交互环境不会自动上传；请确认后增加 --yes。")
    try:
        answer = input("继续构建并提交 Apple 公证？[y/N] ").strip().lower()
    except EOFError:
        return False
    return answer in ("y", "yes")


def install_output(source: Path, destination: Path, allow_overwrite: bool) -> None:
    if destination.exists() and not allow_overwrite:
        raise ReleaseError(f"输出已存在: {destination}；可使用 --force 覆盖。")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary_output = destination.with_name(
        f".{destination.name}.{uuid.uuid4().hex}.tmp"
    )
    try:
        shutil.copy2(source, temporary_output)
        os.replace(temporary_output, destination)
    finally:
        if temporary_output.exists():
            temporary_output.unlink()


def output_path_for_architecture(output_directory: Path, architecture: str) -> Path:
    file_variant = ARCHITECTURE_VARIANTS[architecture][1]
    return output_directory / f"MeloX-macOS-{file_variant}-notarized.dmg"


def run(arguments: argparse.Namespace) -> None:
    require_tools()
    if not ENTITLEMENTS_PATH.is_file():
        raise ReleaseError(f"找不到 macOS entitlements: {ENTITLEMENTS_PATH}")

    authentication = resolve_notary_authentication(arguments)
    print_message(f"✓ 已找到公证凭据: {authentication.description}")
    identity = resolve_signing_identity(arguments.signing_identity)
    print_message(f"✓ Developer ID 签名身份: {identity.name}")
    if arguments.check_only:
        print_message("检查完成：本地签名和公证配置齐全，未构建或上传。")
        return

    architectures = list(dict.fromkeys(arguments.architectures))
    output_directory = Path(arguments.output_directory).expanduser().resolve()
    output_paths = {
        architecture: output_path_for_architecture(output_directory, architecture)
        for architecture in architectures
    }
    existing_outputs = [path for path in output_paths.values() if path.exists()]
    if existing_outputs and not arguments.force:
        raise ReleaseError(
            "输出已存在："
            + ", ".join(str(path) for path in existing_outputs)
            + "；可使用 --force 覆盖。"
        )
    if not confirm_release(
        identity,
        authentication,
        output_paths,
        arguments.yes,
    ):
        print_message("已取消，未构建或上传。")
        return

    if arguments.skip_build:
        configured_apps = {
            "arm64": arguments.app_arm64,
            "x86_64": arguments.app_x86_64,
        }
        app_paths = {
            architecture: Path(configured_apps[architecture]).expanduser().resolve()
            for architecture in architectures
        }
        for architecture, app_path in app_paths.items():
            if not app_path.is_dir():
                raise ReleaseError(
                    f"指定 {ARCHITECTURE_VARIANTS[architecture][0]} App 不存在: "
                    f"{app_path}"
                )
    else:
        app_paths = {
            architecture: path.resolve()
            for architecture, path in build_unsigned_apps(architectures).items()
        }

    expected_metadata: Optional[AppMetadata] = None
    for architecture, app_path in app_paths.items():
        metadata = load_app_metadata(app_path)
        validate_app_architecture(app_path, architecture)
        if expected_metadata is None:
            expected_metadata = metadata
        elif metadata != expected_metadata:
            raise ReleaseError("Apple Silicon 与 Intel App 的版本或 Bundle ID 不一致。")
        print_message(
            f"✓ {ARCHITECTURE_VARIANTS[architecture][0]} App: "
            f"{metadata.bundle_id} {metadata.marketing_version} ({metadata.build_version})"
        )

    temporary_outputs: dict[str, Path] = {}
    submission_ids: dict[str, str] = {}
    with tempfile.TemporaryDirectory(prefix="melox-mac-release-") as temporary_directory:
        temporary_root = Path(temporary_directory)
        for architecture, app_path in app_paths.items():
            variant_name = ARCHITECTURE_VARIANTS[architecture][0]
            variant_root = temporary_root / architecture
            variant_root.mkdir(parents=True)
            signed_app = variant_root / f"{APP_NAME}.app"
            print_message(f"")
            print_message(f"========== 签名公证 {variant_name} 版 ==========")
            run_command(
                ["/usr/bin/ditto", "--norsrc", str(app_path), str(signed_app)],
                f"复制 {variant_name} 待签名 App",
            )
            sign_app(signed_app, identity)

            notarized_dmg = variant_root / output_paths[architecture].name
            create_and_sign_dmg(signed_app, notarized_dmg, identity)
            submission_ids[architecture] = notarize_and_staple(
                notarized_dmg,
                authentication,
            )
            temporary_outputs[architecture] = notarized_dmg

        for architecture, temporary_output in temporary_outputs.items():
            install_output(
                temporary_output,
                output_paths[architecture],
                arguments.force,
            )

    print_message("")
    print_message("完成：已生成分架构的 Developer ID 签名、Apple 公证 DMG。")
    for architecture, output_path in output_paths.items():
        size_mib = output_path.stat().st_size / 1024 / 1024
        print_message(
            f"{ARCHITECTURE_VARIANTS[architecture][0]}: {output_path} "
            f"({size_mib:.1f} MiB，Submission ID: {submission_ids[architecture]})"
        )


def parse_arguments(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="本地构建、Developer ID 签名并公证 MeloX macOS DMG"
    )
    parser.add_argument(
        "--architectures",
        nargs="+",
        choices=ARCHITECTURE_VARIANTS,
        default=list(ARCHITECTURE_VARIANTS),
        help="要生成的架构（默认: arm64 x86_64）",
    )
    parser.add_argument(
        "--output-directory",
        type=Path,
        default=DEFAULT_OUTPUT_DIRECTORY,
        help=f"输出目录（默认: {DEFAULT_OUTPUT_DIRECTORY}）",
    )
    parser.add_argument(
        "--signing-identity",
        default=os.environ.get("MELOX_MAC_SIGNING_IDENTITY"),
        help="Developer ID Application 证书名称或 SHA-1",
    )
    parser.add_argument(
        "--notary-profile",
        help="xcrun notarytool store-credentials 保存的钥匙串配置名",
    )
    parser.add_argument("--api-key", type=Path, help="App Store Connect AuthKey_*.p8")
    parser.add_argument("--key-id", help="App Store Connect API Key ID")
    parser.add_argument("--issuer-id", help="App Store Connect API Issuer ID")
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="跳过构建，签名指定的现有分架构 App",
    )
    parser.add_argument(
        "--app-arm64",
        type=Path,
        default=DEFAULT_APP_PATHS["arm64"],
        help="--skip-build 使用的 Apple Silicon App",
    )
    parser.add_argument(
        "--app-x86-64",
        type=Path,
        default=DEFAULT_APP_PATHS["x86_64"],
        help="--skip-build 使用的 Intel App",
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="只检查本地工具、Developer ID 身份和公证凭据",
    )
    parser.add_argument("--force", action="store_true", help="覆盖已有输出")
    parser.add_argument(
        "--yes",
        action="store_true",
        help="确认将 DMG 上传至 Apple 公证服务",
    )
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    try:
        run(parse_arguments(argv))
        return 0
    except ReleaseError as error:
        print(f"错误: {error}", file=sys.stderr, flush=True)
        return 1
    except KeyboardInterrupt:
        print("\n已取消。", file=sys.stderr, flush=True)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
