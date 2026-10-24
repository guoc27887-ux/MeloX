import QRCode
import SwiftUI

struct WatchQRLoginView: View {
    private enum Status {
        case generating
        case waitingForScan
        case generationFailed
        case expiredRefreshing
        case scannedWaitingForConfirmation
        case loginSucceeded
        case waitingForConfirmation
        case statusCheckFailed

        var title: String {
            switch self {
            case .generating:
                L10n.string("ui.watch.qr.generating")
            case .waitingForScan:
                L10n.string("ui.watch.qr.waiting_scan")
            case .generationFailed:
                L10n.string("ui.watch.qr.generation_failed")
            case .expiredRefreshing:
                L10n.string("ui.watch.qr.expired_refreshing")
            case .scannedWaitingForConfirmation:
                L10n.string("ui.watch.qr.scanned_confirm")
            case .loginSucceeded:
                L10n.string("ui.watch.qr.login_succeeded")
            case .waitingForConfirmation:
                L10n.string("ui.watch.qr.waiting_confirmation")
            case .statusCheckFailed:
                L10n.string("ui.watch.qr.status_check_failed")
            }
        }
    }

    @EnvironmentObject private var account: WatchAccountStore
    @EnvironmentObject private var connectivity: WatchConnectivityStore
    @Environment(\.dismiss) private var dismiss

    let api: WatchNeteaseAPI

    @State private var key: String?
    @State private var qrImage: CGImage?
    @State private var status = Status.generating
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let qrImage {
                    Image(
                        decorative: qrImage,
                        scale: 1,
                        orientation: .up
                    )
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(8)
                    .background(.white, in: .rect(cornerRadius: 14))
                    .accessibilityLabel(
                        L10n.string("ui.watch.qr.accessibility")
                    )
                } else if isLoading {
                    ProgressView()
                        .frame(height: 120)
                }

                Text(status.title)
                    .font(.footnote)
                    .multilineTextAlignment(.center)

                Text("ui.watch.qr.instructions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)

                    Button("ui.watch.qr.regenerate") {
                        Task { await generateAndPoll() }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
        }
        .navigationTitle("ui.watch.qr.title")
        .task {
            await generateAndPoll()
        }
    }

    private func generateAndPoll() async {
        isLoading = true
        errorMessage = nil
        status = .generating
        do {
            let key = try await api.makeQRLoginKey()
            self.key = key
            let url = "https://music.163.com/login?codekey=\(key)"
            qrImage = try? makeQRCode(url)
            isLoading = false
            status = .waitingForScan
            await poll(key: key)
        } catch is CancellationError {
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            status = .generationFailed
        }
    }

    private func poll(key: String) async {
        while !Task.isCancelled, self.key == key {
            do {
                let result = try await api.checkQRLogin(key: key)
                switch result.code {
                case 800:
                    status = .expiredRefreshing
                    await generateAndPoll()
                    return
                case 801:
                    status = .waitingForScan
                case 802:
                    status = .scannedWaitingForConfirmation
                case 803:
                    guard !result.cookie.isEmpty else {
                        throw WatchNeteaseError.invalidResponse
                    }
                    status = .loginSucceeded
                    account.saveQRLogin(
                        cookie: result.cookie,
                        profile: nil
                    )
                    if let profile = try? await api.accountProfile() {
                        account.updateProfile(profile)
                    }
                    connectivity.sendAccountToPhone()
                    dismiss()
                    return
                default:
                    status = .waitingForConfirmation
                }
                try await Task.sleep(for: .seconds(1))
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                status = .statusCheckFailed
                return
            }
        }
    }

    private func makeQRCode(_ string: String) throws -> CGImage {
        let document = try QRCode.Document(
            utf8String: string,
            errorCorrection: .medium
        )
        return try document.cgImage(dimension: 512)
    }
}
