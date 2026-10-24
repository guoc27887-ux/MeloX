import SwiftUI

struct LyricAnnotationLayout: Layout {
    var expansion: CGFloat
    let spacing: CGFloat
    var constrainedWidth: CGFloat? = nil

    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let primaryLyric = subviews.first else {
            return .zero
        }

        let childProposal = constrainedProposal(from: proposal)
        let primarySize = primaryLyric.sizeThatFits(childProposal)
        guard subviews.count > 1 else {
            return CGSize(
                width: childProposal.width ?? primarySize.width,
                height: primarySize.height
            )
        }

        // Measure the collapsed annotation as well so an animated expansion
        // has a stable destination size on its first frame.
        let annotationSize = subviews[1].sizeThatFits(
            childProposal
        )
        return CGSize(
            width: childProposal.width
                ?? max(primarySize.width, annotationSize.width),
            height: primarySize.height
                + clampedExpansion * (spacing + annotationSize.height)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let primaryLyric = subviews.first else { return }

        let childProposal = ProposedViewSize(
            width: bounds.width,
            height: nil
        )
        let primarySize = primaryLyric.sizeThatFits(childProposal)
        primaryLyric.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: childProposal
        )

        guard subviews.count > 1 else { return }
        subviews[1].place(
            at: CGPoint(
                x: bounds.minX,
                y: bounds.minY + primarySize.height + spacing
            ),
            anchor: .topLeading,
            proposal: childProposal
        )
    }

    private var clampedExpansion: CGFloat {
        min(max(expansion, 0), 1)
    }

    private func constrainedProposal(
        from proposal: ProposedViewSize
    ) -> ProposedViewSize {
        ProposedViewSize(
            width: proposal.width ?? constrainedWidth,
            height: nil
        )
    }
}
