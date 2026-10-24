import SwiftUI

/// 第三方音源添加表单：手动填写（URL 模板 + 密钥 + 可选 JS 脚本），
/// 或粘贴导入（JSON / 内嵌配置 / @key 注释头 / 宽松 JS 脚本）。
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
                        Button("ui.unblock.add.import_button") { importPasted() }
                            .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        do {
            let sources = try ThirdPartySourceImportParser.parse(text: pastedText)
            ThirdPartySourceStore.shared.addSources(sources)
            dismiss()
        } catch {
            importError = error.localizedDescription
        }
    }
}
