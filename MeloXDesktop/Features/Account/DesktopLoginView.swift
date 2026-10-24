import SwiftUI
import WebKit

struct DesktopLoginView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("ui.common.cancel") { dismiss() }
                Spacer()
                VStack(spacing: 2) {
                    Text("ui.account.login_netease")
                        .font(.headline)
                    Text("ui.desktop.login.direct_connection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressView()
                    .controlSize(.small)
                    .opacity(isLoading ? 1 : 0)
                    .frame(width: 44)
            }
            .padding(.horizontal, 18)
            .frame(height: 58)

            Divider()

            DesktopNeteaseLoginWebView(isLoading: $isLoading)
                .overlay(alignment: .bottom) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .padding(10)
                            .background(.regularMaterial, in: .capsule)
                            .padding()
                    }
                }
        }
        .frame(width: 880, height: 680)
        .task { await waitForAuthenticatedCookie() }
    }

    private func waitForAuthenticatedCookie() async {
        while !Task.isCancelled {
            if let cookie = await DesktopNeteaseCookieStore.authenticatedCookieHeader() {
                model.settings.cookie = cookie
                await model.accountCookieDidChange()
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

private struct DesktopNeteaseLoginWebView: NSViewRepresentable {
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = DesktopNeteaseCookieStore.dataStore
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: "https://music.163.com/#/login") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let isLoading: Binding<Bool>

        init(isLoading: Binding<Bool>) {
            self.isLoading = isLoading
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation?
        ) {
            isLoading.wrappedValue = true
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation?
        ) {
            isLoading.wrappedValue = false
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation?,
            withError error: Error
        ) {
            isLoading.wrappedValue = false
        }
    }
}

@MainActor
enum DesktopNeteaseCookieStore {
    static let dataStore = WKWebsiteDataStore.default()

    static func authenticatedCookieHeader() async -> String? {
        let cookies = await allCookies().filter(isUsableNeteaseCookie)
        guard cookies.contains(where: { $0.name == "MUSIC_U" && !$0.value.isEmpty }) else {
            return nil
        }
        let values = cookies.reduce(into: [String: String]()) { result, cookie in
            result[cookie.name] = cookie.value
        }
        return values.keys.sorted()
            .map { "\($0)=\(values[$0] ?? "")" }
            .joined(separator: "; ")
    }

    static func clear() async {
        for cookie in await allCookies() where isNeteaseCookie(cookie) {
            await dataStore.httpCookieStore.deleteCookie(cookie)
        }
    }

    private static func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.getAllCookies { continuation.resume(returning: $0) }
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
