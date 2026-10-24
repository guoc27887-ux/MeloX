import SwiftUI

struct DesktopMediaCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let subtitle: String?
    let artworkURL: URL?
    var isCircular = false
    var playCount: Int? = nil
    var showsPlayCount = false
    var action: () -> Void
    var playAction: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: action) {
                    Group {
                        if isCircular {
                            DesktopCircularArtworkView(url: artworkURL)
                        } else {
                            DesktopArtworkView(url: artworkURL, cornerRadius: 9)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .scaleEffect(isHovered ? 1.018 : 1)
                    .shadow(
                        color: .black.opacity(isHovered ? 0.20 : 0.08),
                        radius: isHovered ? 12 : 4,
                        y: isHovered ? 6 : 2
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(title)
                .overlay(alignment: .topTrailing) {
                    if showsPlayCount,
                       let playCount,
                       playCount > 0 {
                        Label(
                            desktopPlayCountText(playCount),
                            systemImage: "play.fill"
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.48), in: .capsule)
                        .padding(8)
                    }
                }

                if let playAction, isHovered {
                    Button(action: playAction) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.red, in: .circle)
                            .shadow(radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .help(L10n.format("ui.common.play_named", title))
                    .transition(.scale.combined(with: .opacity))
                }
            }

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .onHover { hovering in
            withAnimation(
                reduceMotion
                    ? nil
                    : .snappy(duration: 0.24, extraBounce: 0.08)
            ) {
                isHovered = hovering
            }
        }
    }
}

struct DesktopHeroCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let subtitle: String?
    let eyebrow: String?
    let artworkURL: URL?
    var playCount: Int? = nil
    var showsPlayCount = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                DesktopArtworkView(url: artworkURL, cornerRadius: 10)
                    .aspectRatio(1, contentMode: .fill)
                    .scaleEffect(isHovered ? 1.025 : 1)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.08), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 3) {
                    if let eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.66))
                    }
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if subtitle?.isEmpty == false
                        || (showsPlayCount && (playCount ?? 0) > 0) {
                        HStack(spacing: 8) {
                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .lineLimit(2)
                            }
                            if showsPlayCount,
                               let playCount,
                               playCount > 0 {
                                Label(
                                    desktopPlayCountText(playCount),
                                    systemImage: "play.fill"
                                )
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                    }
                }
                .padding(16)
            }
            .clipShape(.rect(cornerRadius: 10, style: .continuous))
            .shadow(
                color: .black.opacity(isHovered ? 0.24 : 0.10),
                radius: isHovered ? 18 : 5,
                y: isHovered ? 9 : 2
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(
                reduceMotion
                    ? nil
                    : .snappy(duration: 0.28, extraBounce: 0.06)
            ) {
                isHovered = hovering
            }
        }
    }
}

private func desktopPlayCountText(_ count: Int) -> String {
    count.formatted(
        .number.notation(.compactName).locale(L10n.locale)
    )
}

struct DesktopSectionHeader: View {
    let title: String
    var trailingTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 23, weight: .bold))
            Spacer()
            if let trailingTitle, let action {
                Button(trailingTitle, action: action)
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
            }
        }
    }
}
