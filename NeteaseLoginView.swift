import SwiftUI
import WebKit

struct NeteaseLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var model = NeteaseWebViewModel()

    var body: some View {
        NeteaseWebViewRepresentable(model: model)
            .ignoresSafeArea(.container, edges: .bottom)
            .overlay(alignment: .top) {
                if model.isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }
            .navigationTitle("登录网易云音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task {
                model.load(URL(string: "https://music.163.com/#"))
                await waitForAuthenticatedCookie()
            }
    }

    private func waitForAuthenticatedCookie() async {
        while !Task.isCancelled {
            if let cookieHeader = await NeteaseWebCookieStore.authenticatedCookieHeader() {
                settings.cookie = cookieHeader
                await library.refresh(force: true)
                dismiss()
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
        }
    }
}

// iOS 26 的 SwiftUI WebView / WebPage 在 iOS 18 上不存在,
// 这里用 WKWebView + UIViewRepresentable 提供等价能力。
@MainActor
@Observable
final class NeteaseWebViewModel {
    var isLoading = false

    @ObservationIgnored
    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = NeteaseWebCookieStore.dataStore
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }()

    func load(_ url: URL?) {
        guard let url else { return }
        webView.load(URLRequest(url: url))
    }
}

struct NeteaseWebViewRepresentable: UIViewRepresentable {
    let model: NeteaseWebViewModel

    func makeUIView(context: Context) -> WKWebView {
        let webView = model.webView
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let model: NeteaseWebViewModel

        init(model: NeteaseWebViewModel) {
            self.model = model
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            model.isLoading = true
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            model.isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            model.isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            model.isLoading = false
        }
    }
}

@MainActor
enum NeteaseWebCookieStore {
    static let dataStore = WKWebsiteDataStore.default()

    static func authenticatedCookieHeader() async -> String? {
        let cookies = await allCookies().filter(isUsableNeteaseCookie)
        guard cookies.contains(where: { $0.name == "MUSIC_U" && !$0.value.isEmpty }) else {
            return nil
        }

        let values = cookies.reduce(into: [String: String]()) { result, cookie in
            result[cookie.name] = cookie.value
        }
        return values.keys.sorted().map { "\($0)=\(values[$0] ?? "")" }.joined(separator: "; ")
    }

    static func clear() async {
        for cookie in await allCookies() where isNeteaseCookie(cookie) {
            await dataStore.httpCookieStore.deleteCookie(cookie)
        }
    }

    private static func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    private static func isUsableNeteaseCookie(_ cookie: HTTPCookie) -> Bool {
        isNeteaseCookie(cookie) && (cookie.expiresDate.map { $0 > Date() } ?? true)
    }

    private static func isNeteaseCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return domain == "163.com" || domain.hasSuffix(".163.com")
    }
}
