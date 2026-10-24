import Foundation
import SwiftUI

/// 第三方音源添加表单：手动填写（URL 模板 + 密钥 + 可选 JS 脚本），
/// 或粘贴导入（JSON / 内嵌配置 / @key 注释头 / 宽松 JS 脚本 / 裸链接下载后解析）。
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
}
