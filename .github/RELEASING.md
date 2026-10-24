# MeloX Release Guide / MeloX 发版规则

[English](#english) | [简体中文](#简体中文)

## English

### Release Notes

`RELEASE_NOTES.md` always contains both platform sections:

- `iOS + Apple Watch`: a non-empty section builds and publishes the IPA.
- `macOS`: a non-empty section builds and publishes separate Apple silicon and Intel DMGs.

Every platform section must include both `### 简体中文` and `### English`. Translations must contain the same number of entries in the same order. CI rejects missing language sections or mismatched entry counts.

Branch, pull-request, and `main` builds select artifacts from the non-empty platform sections. If both platform sections contain entries, CI builds both sets of artifacts.

The build generates a schema-version-3 `ReleaseNotes.json` containing `localizedEntries` for `zh-Hans` and `en`. The apps select one array from their active language. GitHub Release and Telegram consume the bilingual `ReleaseNotes.md` artifact.

### Tags and Versions

- iOS + Apple Watch: `v<major>.<minor>.<patch>`, for example `v1.2.0`.
- macOS: `v<major>.<minor>.<patch>_mac`, for example `v0.1.0_mac`.

To release both platforms together, point both tags at the same commit and push them together. Each tag creates an independent GitHub Release and an independent bilingual Telegram release message.

The macOS Release does not replace the repository's Latest release. Latest remains assigned to mobile for compatibility with older iOS clients that still request `/releases/latest`.

GitHub Actions produces `MeloX-macOS-Apple-Silicon.dmg` and `MeloX-macOS-Intel.dmg` as unsigned builds. The GitHub Release body and website Release area retain Gatekeeper instructions. The platform download menu labels these builds as unsigned without embedding the `xattr` command in the menu itself.

macOS DMGs distributed through the cloud drive are built locally with `Tools/MacRelease/build_macos_release.py`. Apple silicon (`arm64`) and Intel (`x86_64`) are built, signed, and notarized separately. The website may label these downloads as notarized only after the tool completes Developer ID signing, Apple notarization, ticket stapling, and Gatekeeper verification for both DMGs. The bilingual Telegram release message also directs users to the website for signed and notarized builds.

## 简体中文

### 更新日志

`RELEASE_NOTES.md` 固定包含两个平台区块：

- `iOS + Apple Watch`：非空时构建并发布 IPA。
- `macOS`：非空时分别构建并发布 Apple Silicon 与 Intel DMG。

每个平台区块必须同时包含 `### 简体中文` 与 `### English`，中英文条目数量及顺序必须一一对应。缺少任一语言或条目数量不一致时，CI 会直接失败。

普通分支、Pull Request 与 `main` 构建会根据非空区块选择产物。两个平台区块都有内容时，会分别构建两份产物。

构建过程会生成 schema version 3 的 `ReleaseNotes.json`，其中 `localizedEntries` 分别保存 `zh-Hans` 与 `en` 条目。App 根据当前语言选择对应数组；GitHub Release 与 Telegram 则使用双语 `ReleaseNotes.md` 产物。

### 标签与版本

- iOS + Apple Watch：`v<major>.<minor>.<patch>`，例如 `v1.2.0`。
- macOS：`v<major>.<minor>.<patch>_mac`，例如 `v0.1.0_mac`。

两端同时发版时，将两个标签指向同一个 Commit 并一起推送。每个标签会独立创建 GitHub Release，并独立发送一条双语 Telegram 发版消息。

macOS Release 不会替换仓库的 Latest；Latest 始终保留给移动端，以兼容仍请求 `/releases/latest` 的旧版 iOS 客户端。

GitHub Actions 生成 `MeloX-macOS-Apple-Silicon.dmg` 和 `MeloX-macOS-Intel.dmg`，两者仅作为未签名构建发布。GitHub Release 正文和官网 Release 区域保留 Gatekeeper 处理说明；“选择平台下载”下拉菜单只标注“未签名”，不附带 `xattr` 文案。

网盘中的 macOS DMG 使用 `Tools/MacRelease/build_macos_release.py` 在本地生成。Apple Silicon（`arm64`）与 Intel（`x86_64`）分别构建、签名和公证。只有该工具完成两份 DMG 的 Developer ID 签名、Apple 公证、票据装订和 Gatekeeper 验证后，官网网盘入口才标注“已公证”。双语 macOS Telegram 发版消息同时说明，已签名公证版需前往官网获取。
