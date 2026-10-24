import SwiftUI
import UIKit

struct LyricsSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let store: LyricShareSelectionStore

    @State private var replacementIndex: Int?
    @State private var sharePayload: LyricSharePayload?

    init(store: LyricShareSelectionStore) {
        self.store = store
    }

    var body: some View {
        VStack(spacing: 0) {
            songHeader
            selectionSummary
            Divider()
            lyricsList
        }
        .background(.regularMaterial)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            shareControl
        }
        .alert(
            "ui.lyrics.share.replace_confirmation",
            isPresented: replacementAlertBinding
        ) {
            Button("ui.common.replace", role: .destructive) {
                guard let replacementIndex else { return }
                store.replaceSelection(with: replacementIndex)
                self.replacementIndex = nil
            }
            Button("ui.common.cancel", role: .cancel) {
                replacementIndex = nil
            }
        } message: {
            Text(
                L10n.format(
                    "ui.lyrics.share.character_limit_message",
                    store.characterLimit
                )
            )
        }
        .sheet(item: $sharePayload) { payload in
            LyricsShareSheet(
                payload: payload,
                artwork: store.artwork,
                onComplete: { _ in
                    sharePayload = nil
                    dismiss()
                }
            )
        }
    }

    private var songHeader: some View {
        HStack(spacing: 12) {
            Group {
                if let artwork = store.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 52, height: 52)
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(store.presentation.song.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(store.presentation.song.artistText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(selectionTitle)
                .font(.title3.weight(.semibold))
            Text(selectionSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .animation(.smooth(duration: 0.22), value: store.selectedLineCount)
        .animation(
            .smooth(duration: 0.22),
            value: store.selectedCharacterCount
        )
    }

    private var lyricsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(store.presentation.lyrics.indices, id: \.self) {
                        index in
                        let lyric = store.presentation.lyrics[index]
                        LyricsSelectionRow(
                            lyric: lyric,
                            state: store.rowState(at: index)
                        ) {
                            handleLyricTap(at: index)
                        }
                        .id(lyric.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 19)
            }
            .onAppear {
                proxy.scrollTo(
                    store.presentation.initialLyricID,
                    anchor: .center
                )
            }
        }
    }

    private var shareControl: some View {
        Button {
            sharePayload = store.payload
        } label: {
            Label(
                "ui.lyrics.share.title",
                systemImage: "square.and.arrow.up"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(!store.canShare)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var selectionTitle: String {
        let count = store.selectedLineCount
        return count == 0
            ? L10n.string("ui.lyrics.share.none_selected")
            : L10n.format("ui.lyrics.share.selected_lines", count)
    }

    private var selectionSubtitle: String {
        guard store.selectedLineCount > 0 else {
            return L10n.string("ui.lyrics.share.select_hint")
        }
        return L10n.format(
            "ui.lyrics.share.character_count",
            store.selectedCharacterCount,
            store.characterLimit
        )
    }

    private var replacementAlertBinding: Binding<Bool> {
        Binding(
            get: { replacementIndex != nil },
            set: { isPresented in
                if !isPresented {
                    replacementIndex = nil
                }
            }
        )
    }

    private func handleLyricTap(at index: Int) {
        switch store.tapLyric(at: index) {
        case .changed, .ignored:
            break
        case .requiresReplacement(let index):
            replacementIndex = index
        }
    }
}

private struct LyricsSelectionRow: View {
    let lyric: LyricLine
    let state: LyricsSelectionManager.RowState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(lyric.text)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background {
                    if let position = selectionPosition {
                        selectionBackground(for: position)
                            .fill(Color.accentColor.opacity(0.2))
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(state == .disabled)
        .opacity(state == .disabled ? 0.32 : 1)
        .accessibilityAddTraits(
            selectionPosition == nil ? [] : .isSelected
        )
    }

    private var selectionPosition:
        LyricsSelectionManager.SelectionPosition?
    {
        guard case .selected(let position) = state else { return nil }
        return position
    }

    private func selectionBackground(
        for position: LyricsSelectionManager.SelectionPosition
    ) -> UnevenRoundedRectangle {
        let radius: CGFloat = 16
        switch position {
        case .single:
            return UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: radius,
                    bottomLeading: radius,
                    bottomTrailing: radius,
                    topTrailing: radius
                ),
                style: .continuous
            )
        case .first:
            return UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: radius,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: radius
                ),
                style: .continuous
            )
        case .middle:
            return UnevenRoundedRectangle(
                cornerRadii: .init(),
                style: .continuous
            )
        case .last:
            return UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 0,
                    bottomLeading: radius,
                    bottomTrailing: radius,
                    topTrailing: 0
                ),
                style: .continuous
            )
        }
    }
}
