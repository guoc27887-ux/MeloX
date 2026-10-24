import Foundation
import SwiftUI

/// 第三方音源添加表单：手动填写（URL 模板 + 密钥 + 可选 JS 脚本），
/// 或粘贴导入（JSON / 内嵌配置 / @key 注释头 / 宽松 JS 脚本 / 裸链接下载后解析，
/// 含 plugins 清单链接逐个下载分平台条目）。
/// 只保存用户自己填入的配置，不内置任何音源与密钥。
struct ThirdPartySourceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable {
        case manual
        case paste
    }

    @State private var mode: Mode = .manual
    @State private var name = ""
    @State private var template = ""
    @State private var keys = ""
    @State private var platform = "any"
    @State private var quality: ThirdPartyAudioQuality = .kb320
    @State private var urlPath = "url"
    @State private var script = ""
    @State private var pastedText = ""
    @State private var importError: String?
    @State private var isImportingLink = false

    private var manualCanSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("ui.unblock.add.mode", selection: $mode) {
                        Text("ui.unblock.add.manual").tag(Mode.manual)
                        Text("ui.unblock.add.import").tag(Mode.paste)
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .manual {
                    Section {
                        TextField("ui.unblock.add.name", text: $name)
                        TextField("ui.unblock.add.template", text: $template)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("ui.unblock.add.keys", text: $keys)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Picker("ui.unblock.add.platform", selection: $platform) {
                            Text("ui.unblock.platform.any").tag("any")
                            Text(verbatim: "wy").tag("wy")
                            Text(verbatim: "tx").tag("tx")
                            Text(verbatim: "kg").tag("kg")
                        }
                        Picker("ui.unblock.add.quality", selection: $quality) {
                            ForEach(ThirdPartyAudioQuality.allCases) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        TextField("ui.unblock.add.url_path", text: $urlPath)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("ui.unblock.add.template_hint")
                    }

                    Section {
                        TextEditor(text: $script)
                            .frame(minHeight: 140)
                            .autocorrectionDisabled()
                    } header: {
                        Text("ui.unblock.add.script")
                    } footer: {
                        Text("ui.unblock.add.script_hint")
                    }
                } else {
                    Section {
                        TextEditor(text: $pastedText)
                            .frame(minHeight: 220)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("ui.unblock.add.import_hint")
                    }
                }
            }
            .navigationTitle("ui.unblock.add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ui.common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if mode == .manual {
                        Button("ui.common.done") { saveManual() }
                            .disabled(!manualCanSave)
                    } else {
                        Button {
                            importPasted()
                        } label: {
                            if isImportingLink {
                                ProgressView()
                            } else {
                                Text("ui.unblock.add.import_button")
                            }
                        }
                        .disabled(isImportingLink || pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert(
                "ui.unblock.add.import_error",
                isPresented: Binding(
                    get: { importError != nil },
                    set: { if !$0 { importError = nil } }
                )
            ) {
                Button("ui.common.done", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func saveManual() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedScript = script.trimmingCharacters(in: .whitespacesAndNewlines)
        var headers: [String: String] = [:]
        if platform != "any" {
            headers["source"] = platform
        }
        let trimmedKeys = keys.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKeys.isEmpty {
            headers["apiKeys"] = trimmedKeys
        }
        let trimmedURLPath = urlPath.trimmingCharacters(in: .whitespacesAndNewlines)
        ThirdPartySourceStore.shared.addSource(ThirdPartySource(
            name: trimmedName,
            kind: trimmedScript.isEmpty ? "keyword" : "script",
            template: trimmedTemplate,
            urlPath: trimmedURLPath.isEmpty ? "url" : trimmedURLPath,
            headers: headers,
            quality: quality.rawValue,
            script: trimmedScript.isEmpty ? nil : trimmedScript,
            enabled: true
        ))
        dismiss()
    }

    private func importPasted() {
        let trimmed = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = sourceLinkURL(from: trimmed) {
            importFromLink(url)
            return
        }
        do {
            let sources = try ThirdPartySourceImportParser.parse(text: pastedText)
            ThirdPartySourceStore.shared.addSources(sources)
            dismiss()
        } catch {
            importError = error.localizedDescription
        }
    }

    /// 裸链接识别：trim 后以 http(s):// 开头、中间不含任何空白或换行，
    /// 且能解析为带 host 的 http(s) URL。带前后文的文本不算链接，走原有文本解析。
    private func sourceLinkURL(from trimmed: String) -> URL? {
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"),
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }

    /// 链接导入：先下载（15 秒超时），再走现有文本解析入库。
    /// 下载类问题报“链接下载失败”，内容类问题报“内容解析失败”，共用现有 importError 弹窗。
    private func importFromLink(_ url: URL) {
        isImportingLink = true
        importError = nil
        Task {
            // 第一步：下载。网络错误（含超时）、非 2xx、空内容都算下载失败。
            let downloadedText: String
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    await MainActor.run {
                        isImportingLink = false
                        importError = "链接下载失败：HTTP 状态码 \(status)"
                    }
                    return
                }
                guard !data.isEmpty else {
                    await MainActor.run {
                        isImportingLink = false
                        importError = "链接下载失败：返回内容为空"
                    }
                    return
                }
                guard let text = String(data: data, encoding: .utf8)
                        ?? String(data: data, encoding: .utf16)
                        ?? String(data: data, encoding: .unicode) else {
                    await MainActor.run {
                        isImportingLink = false
                        importError = "内容解析失败：内容不是有效的文本"
                    }
                    return
                }
                downloadedText = text
            } catch {
                await MainActor.run {
                    isImportingLink = false
                    importError = "链接下载失败：\(error.localizedDescription)"
                }
                return
            }
            // 清单格式：JSON 对象顶层含 plugins 数组时，不走原有 parse(text:)，
            // 而是逐个下载清单里的条目链接再解析入库。
            if let entries = manifestEntries(from: downloadedText) {
                await importFromManifest(entries)
                return
            }
            // 第二步：解析。解析器抛出的错误（unsupported / noValidSource 等）都算内容解析失败。
            do {
                let sources = try ThirdPartySourceImportParser.parse(text: downloadedText)
                await MainActor.run {
                    isImportingLink = false
                    ThirdPartySourceStore.shared.addSources(sources)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isImportingLink = false
                    importError = "内容解析失败：\(error.localizedDescription)"
                }
            }
        }
    }

    /// 清单识别：文本须为 JSON 对象，顶层 plugins 为数组，且至少含一个
    /// name 非空、url 为带 host 的 http(s) 链接的有效条目；否则返回 nil，走原有解析。
    /// 这里只做格式识别，不内置任何音源地址与密钥。
    private func manifestEntries(from text: String) -> [(name: String, url: URL)]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = object["plugins"] as? [[String: Any]] else { return nil }
        var entries: [(name: String, url: URL)] = []
        for item in plugins {
            guard let name = item["name"] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let urlString = item["url"] as? String,
                  let url = URL(string: urlString),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  url.host != nil else { continue }
            entries.append((name: name, url: url))
        }
        return entries.isEmpty ? nil : entries
    }

    /// 清单条目下载失败的原因（仅用于区分计数，不改现有“链接下载失败”文案）。
    private enum ManifestImportError: LocalizedError {
        case download(String)
        var errorDescription: String? {
            switch self {
            case .download(let reason): return reason
            }
        }
    }

    /// 清单条目下载：15 秒超时。网络错误、非 2xx、空内容、非文本都算下载失败。
    private func downloadText(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ManifestImportError.download(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ManifestImportError.download("HTTP 状态码 \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        guard !data.isEmpty else {
            throw ManifestImportError.download("返回内容为空")
        }
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .unicode) else {
            throw ManifestImportError.download("内容不是有效的文本")
        }
        return text
    }

    /// 清单导入：顺序逐个下载条目链接（不并发），每个下载到的文本走现有解析器。
    /// 名称优先用清单里的 name；至少一个成功即算成功并关闭表单；
    /// 全部失败时报“内容解析失败”并带原因。进行中状态沿用 isImportingLink。
    private func importFromManifest(_ entries: [(name: String, url: URL)]) async {
        var imported: [ThirdPartySource] = []
        var downloadFailures = 0
        var parseFailures = 0
        var lastReason = ""
        for entry in entries {
            do {
                let text = try await downloadText(from: entry.url)
                let sources = try ThirdPartySourceImportParser.parse(text: text)
                imported.append(contentsOf: sources.map { source in
                    var renamed = source
                    renamed.name = entry.name
                    return renamed
                })
            } catch let error as ManifestImportError {
                downloadFailures += 1
                lastReason = error.localizedDescription
            } catch {
                parseFailures += 1
                lastReason = error.localizedDescription
            }
        }
        await MainActor.run {
            isImportingLink = false
            if !imported.isEmpty {
                ThirdPartySourceStore.shared.addSources(imported)
                dismiss()
            } else {
                importError = "内容解析失败：清单中的 \(entries.count) 个音源均导入失败（下载失败 \(downloadFailures) 个，解析失败 \(parseFailures) 个）"
                    + (lastReason.isEmpty ? "" : "，原因：\(lastReason)")
            }
        }
    }
}
