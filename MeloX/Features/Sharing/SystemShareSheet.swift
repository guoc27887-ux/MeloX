import SwiftUI
import UIKit

struct SystemShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: ((Bool) -> Void)?

    init(
        activityItems: [Any],
        onComplete: ((Bool) -> Void)? = nil
    ) {
        self.activityItems = activityItems
        self.onComplete = onComplete
    }

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        let viewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        viewController.completionWithItemsHandler = {
            _, completed, _, _ in
            onComplete?(completed)
        }
        return viewController
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
