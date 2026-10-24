import SwiftUI

nonisolated enum LyricSupplementalTextRole: Hashable {
    case primary
    case transliteration
    case translation
}

nonisolated private struct LyricSupplementalTextRoleKey: LayoutValueKey {
    static let defaultValue = LyricSupplementalTextRole.primary
}

extension View {
    func lyricSupplementalTextRole(
        _ role: LyricSupplementalTextRole
    ) -> some View {
        layoutValue(key: LyricSupplementalTextRoleKey.self, value: role)
    }
}

/// A stable three-layer lyric row. Visibility changes resize only the
/// supplemental layers, so enabling pronunciation never swaps or rewraps the
/// primary lyric view tree.
struct LyricSupplementalTextLayout: Layout {
    var transliterationExpansion: CGFloat
    var translationExpansion: CGFloat
    let transliterationSpacing: CGFloat
    let translationSpacing: CGFloat
    let translationBottomPadding: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            AnimatablePair(
                transliterationExpansion,
                translationExpansion
            )
        }
        set {
            transliterationExpansion = newValue.first
            translationExpansion = newValue.second
        }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let primary = subview(.primary, in: subviews) else {
            return .zero
        }

        let childProposal = ProposedViewSize(
            width: proposal.width,
            height: nil
        )
        let primarySize = primary.sizeThatFits(childProposal)
        let transliterationSize = subview(
            .transliteration,
            in: subviews
        )?.sizeThatFits(childProposal) ?? .zero
        let translationSize = subview(
            .translation,
            in: subviews
        )?.sizeThatFits(childProposal) ?? .zero

        let transliterationContribution =
            clampedTransliterationExpansion
            * (
                transliterationSpacing
                    + transliterationSize.height
            )
        let translationContribution =
            clampedTranslationExpansion
            * (
                translationSpacing
                    + translationSize.height
                    + translationBottomPadding
            )
        return CGSize(
            width: proposal.width
                ?? max(
                    primarySize.width,
                    transliterationSize.width,
                    translationSize.width
                ),
            height: primarySize.height
                + transliterationContribution
                + translationContribution
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let primary = subview(.primary, in: subviews) else {
            return
        }
        let childProposal = ProposedViewSize(
            width: bounds.width,
            height: nil
        )
        let primarySize = primary.sizeThatFits(childProposal)
        primary.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: childProposal
        )

        var cursorY = bounds.minY + primarySize.height
        if let transliteration = subview(
            .transliteration,
            in: subviews
        ) {
            let size = transliteration.sizeThatFits(childProposal)
            transliteration.place(
                at: CGPoint(
                    x: bounds.minX,
                    y: cursorY + transliterationSpacing
                ),
                anchor: .topLeading,
                proposal: childProposal
            )
            cursorY += clampedTransliterationExpansion
                * (transliterationSpacing + size.height)
        }

        if let translation = subview(.translation, in: subviews) {
            translation.place(
                at: CGPoint(
                    x: bounds.minX,
                    y: cursorY + translationSpacing
                ),
                anchor: .topLeading,
                proposal: childProposal
            )
        }
    }

    private func subview(
        _ role: LyricSupplementalTextRole,
        in subviews: Subviews
    ) -> LayoutSubview? {
        subviews.first {
            $0[LyricSupplementalTextRoleKey.self] == role
        }
    }

    private var clampedTransliterationExpansion: CGFloat {
        min(max(transliterationExpansion, 0), 1)
    }

    private var clampedTranslationExpansion: CGFloat {
        min(max(translationExpansion, 0), 1)
    }
}
