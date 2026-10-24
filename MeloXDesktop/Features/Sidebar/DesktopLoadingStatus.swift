import SwiftUI

struct DesktopLoadingStatusPreferenceKey: PreferenceKey {
    static let defaultValue: String? = nil

    static func reduce(
        value: inout String?,
        nextValue: () -> String?
    ) {
        value = nextValue() ?? value
    }
}

extension View {
    func desktopLoadingStatus(
        _ message: String,
        isPresented: Bool
    ) -> some View {
        preference(
            key: DesktopLoadingStatusPreferenceKey.self,
            value: isPresented ? message : nil
        )
    }
}
