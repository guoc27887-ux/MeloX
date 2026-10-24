import SwiftUI
import UIKit

struct FloatingLyricsPictureInPictureSource: UIViewRepresentable {
    static let sourceSize = CGSize(width: 96, height: 32)

    let controller: FloatingLyricsController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> SourceView {
        let view = SourceView()
        view.controller = controller
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        view.layer.masksToBounds = true
        controller.attachDisplayLayer(
            to: view.layer,
            bounds: view.bounds
        )
        return view
    }

    func updateUIView(_ view: SourceView, context: Context) {
        view.controller = controller
        controller.updateDisplayLayerFrame(view.bounds)
    }

    static func dismantleUIView(
        _ view: SourceView,
        coordinator: Coordinator
    ) {
        MainActor.assumeIsolated {
            coordinator.controller.detachDisplayLayer(from: view.layer)
            view.controller = nil
        }
    }

    final class SourceView: UIView {
        weak var controller: FloatingLyricsController?

        override func layoutSubviews() {
            super.layoutSubviews()
            controller?.updateDisplayLayerFrame(bounds)
        }
    }

    final class Coordinator {
        let controller: FloatingLyricsController

        init(controller: FloatingLyricsController) {
            self.controller = controller
        }
    }
}
