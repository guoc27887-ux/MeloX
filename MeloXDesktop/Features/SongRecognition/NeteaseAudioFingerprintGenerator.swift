import Foundation
@preconcurrency import WebKit

enum NeteaseAudioFingerprintError: LocalizedError {
    case resourcesMissing
    case runtimeFailed(String)
    case invalidResult

    var errorDescription: String? {
        switch self {
        case .resourcesMissing:
            L10n.string("ui.recognition.error.fingerprint_resources")
        case .runtimeFailed(let message):
            L10n.format("ui.recognition.error.fingerprint_failed", message)
        case .invalidResult:
            L10n.string("ui.recognition.error.fingerprint_invalid")
        }
    }
}

@MainActor
final class NeteaseAudioFingerprintGenerator:
    NSObject,
    WKNavigationDelegate {
    private var webView: WKWebView?
    private var preparationContinuation:
        CheckedContinuation<Void, Error>?
    private var isPrepared = false

    func generate(from samples: [Float]) async throws -> String {
        guard !samples.isEmpty else {
            throw NeteaseAudioFingerprintError.invalidResult
        }

        try await prepare()
        try Task.checkCancellation()
        guard let webView else {
            throw NeteaseAudioFingerprintError.invalidResult
        }

        let pcmData = samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return Data()
            }
            return Data(
                bytes: baseAddress,
                count: buffer.count * MemoryLayout<Float>.size
            )
        }

        let script = """
        const bytes = Uint8Array.from(
            atob(pcm),
            character => character.charCodeAt(0)
        );
        const sampleCount = Math.floor(bytes.byteLength / 4);
        const floatSamples = new Float32Array(
            bytes.buffer,
            bytes.byteOffset,
            sampleCount
        );
        return await GenerateFP(floatSamples);
        """

        let result: Any?
        do {
            result = try await webView.callAsyncJavaScript(
                script,
                arguments: ["pcm": pcmData.base64EncodedString()],
                in: nil,
                contentWorld: .page
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NeteaseAudioFingerprintError.runtimeFailed(
                error.localizedDescription
            )
        }

        try Task.checkCancellation()
        guard let fingerprint = result as? String,
              let decoded = Data(base64Encoded: fingerprint),
              !decoded.isEmpty else {
            throw NeteaseAudioFingerprintError.invalidResult
        }
        return fingerprint
    }

    private func prepare() async throws {
        if isPrepared {
            return
        }
        guard preparationContinuation == nil else {
            throw NeteaseAudioFingerprintError.runtimeFailed(
                L10n.string("ui.recognition.error.fingerprint_initializing")
            )
        }

        guard let wasmSource = bundledText(
            named: "afp.wasm",
            extension: "js"
        ),
        let fingerprintSource = bundledText(
            named: "afp",
            extension: "js"
        ) else {
            throw NeteaseAudioFingerprintError.resourcesMissing
        }

        let prelude = """
        globalThis.require = function(path) {
            if (path.includes('logger')) {
                return {
                    info: function() {},
                    warn: function() {},
                    error: function() {}
                };
            }
            if (path.includes('afp.wasm')) {
                return { WASM_BINARY: WASM_BINARY };
            }
            throw new Error('Unsupported local module: ' + path);
        };
        """

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences
            .allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: [prelude, wasmSource, fingerprintSource]
                    .joined(separator: "\n"),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        let runtimeWebView = WKWebView(
            frame: .zero,
            configuration: configuration
        )
        runtimeWebView.navigationDelegate = self
        webView = runtimeWebView

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                preparationContinuation = continuation
                runtimeWebView.loadHTMLString(
                    "<!doctype html><html><body></body></html>",
                    baseURL: nil
                )
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelPreparation()
            }
        }
    }

    private func bundledText(
        named name: String,
        extension fileExtension: String
    ) -> String? {
        let candidateURLs = [
            Bundle.main.url(
                forResource: name,
                withExtension: fileExtension,
                subdirectory: "AudioFingerprint"
            ),
            Bundle.main.url(
                forResource: name,
                withExtension: fileExtension,
                subdirectory: "Resources/AudioFingerprint"
            ),
            Bundle.main.url(
                forResource: name,
                withExtension: fileExtension
            ),
        ]
        guard let url = candidateURLs.compactMap({ $0 }).first else {
            return nil
        }
        return try? String(
            contentsOf: url,
            encoding: .utf8
        )
    }

    private func cancelPreparation() {
        webView?.stopLoading()
        webView = nil
        finishPreparation(.failure(CancellationError()))
    }

    private func finishPreparation(
        _ result: Result<Void, Error>
    ) {
        guard let continuation = preparationContinuation else {
            return
        }
        preparationContinuation = nil

        switch result {
        case .success:
            isPrepared = true
            continuation.resume()
        case .failure(let error):
            isPrepared = false
            webView = nil
            continuation.resume(throwing: error)
        }
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        finishPreparation(.success(()))
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finishPreparation(
            .failure(
                NeteaseAudioFingerprintError.runtimeFailed(
                    error.localizedDescription
                )
            )
        )
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finishPreparation(
            .failure(
                NeteaseAudioFingerprintError.runtimeFailed(
                    error.localizedDescription
                )
            )
        )
    }
}
