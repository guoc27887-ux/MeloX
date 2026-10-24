# MeloX macOS 本地签名公证

GitHub Actions 继续发布未签名 DMG，但 Apple 芯片和 Intel 分别构建，不使用 Universal 二进制。网盘发布使用本工具生成的两份产物：

- `build/MeloX-macOS-Apple-Silicon-notarized.dmg`：Apple 芯片（M 系列，`arm64`）。
- `build/MeloX-macOS-Intel-notarized.dmg`：Intel（`x86_64`）。

默认流程只有在两份 DMG 都完成 Developer ID 签名、Apple 公证、票据装订和 Gatekeeper 验证后，才会将它们写入最终输出目录。使用 `--architectures` 显式只选一个架构时，则只处理该产物。

## 前置条件

- 登录钥匙串已导入 `Developer ID Application` 证书及其私钥。
- App Store Connect API `.p8` 可用于公证。默认会复用 `Tools/TestFlightUploader/.credentials/AuthKey_*.p8`，并从本地 TestFlight 脚本读取 Key ID 和 Issuer ID。
- 也可使用 `ASC_PRIVATE_KEY_PATH`、`ASC_KEY_ID`、`ASC_ISSUER_ID`，或通过命令行参数覆盖。

`.p8` 是公证 API 凭据，不是 Developer ID 代码签名证书。iOS `.mobileprovision` 中的证书公钥也无法代替 Mac 签名所需的私钥。

## 使用

```bash
python3 Tools/MacRelease/build_macos_release.py --check-only
python3 Tools/MacRelease/build_macos_release.py
```

非交互环境需要显式增加 `--yes`。如果已通过 `notarytool store-credentials` 保存公证凭据，可使用：

```bash
python3 Tools/MacRelease/build_macos_release.py \
  --notary-profile MeloX-notary
```

如果只需要某一架构，可显式指定：

```bash
python3 Tools/MacRelease/build_macos_release.py --architectures arm64
python3 Tools/MacRelease/build_macos_release.py --architectures x86_64
```

上传网盘前，确认脚本最后同时列出 Apple Silicon 和 Intel 两份 DMG 及各自的 Submission ID。
