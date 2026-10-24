import SwiftUI
import WebKit

/// Chooser: SwiftUI's `WebView`/`WebPage` are iOS 26 only, so iOS 18 gets a
/// WKWebView-based login view. Both load the same page from the same website
/// data store, so the cookie polling below works identically on either path.
struct NeteaseLoginView: View {
    var body: some View {
        if #available(iOS 26, *) {
            NeteaseLoginView26()
        } else {
            NeteaseLoginViewLegacy()
        }
    }
}

@available(iOS 26, *)
private struct NeteaseLoginView26: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var page: WebPage

    init() {
        _page = State(initialValue: NeteaseWebCookieStore.makePage())
    }

    var body: some View {
        WebView(page)
            .webViewBackForwardNavigationGestures(.enabled)
            .overlay(alignment: .top) {
                if page.isLoading {
                    ProgressView(value: page.estimatedProgress)
                        .progressViewStyle(.linear)
                }
            }
            .navigationTitle("ui.settings.account.login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ui.common.cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task {
                _ = page.load(URL(string: "https://music.163.com/#"))
                await waitForNeteaseAuthenticatedCookie(
                    settings: settings,
                    library: library,
                    dismiss: dismiss
                )
            }
    }
}

/// iOS 18 login view: same page, same cookie store, plain WKWebView.
private struct NeteaseLoginViewLegacy: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var isLoading = false

    var body: some View {
        LegacyNeteaseWebView(isLoading: $isLoading)
            .overlay(alignment: .top) {
                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("ui.settings.account.login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ui.common.cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task {
                await waitForNeteaseAuthenticatedCookie(
                    settings: settings,
                    library: library,
                    dismiss: dismiss
                )
            }
    }
}

private struct LegacyNeteaseWebView: UIViewRepresentable {
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://music.163.com/#")!))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var isLoading: Binding<Bool>

        init(isLoading: Binding<Bool>) {
            self.isLoading = isLoading
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            isLoading.wrappedValue = true
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            isLoading.wrappedValue = false
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            isLoading.wrappedValue = false
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            isLoading.wrappedValue = false
        }
    }
}

@MainActor
private func waitForNeteaseAuthenticatedCookie(
    settings: AppSettings,
    library: LibraryStore,
    dismiss: DismissAction
) async {
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

@MainActor
enum NeteaseWebCookieStore {
    private static let dataStore = WKWebsiteDataStore.default()

    @available(iOS 26, *)
    static func makePage() -> WebPage {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = dataStore
        configuration.defaultNavigationPreferences.preferredContentMode = .desktop
        return WebPage(configuration: configuration)
    }

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
