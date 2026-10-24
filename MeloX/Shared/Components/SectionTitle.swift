import SwiftUI

struct SectionTitle: View {
    let title: String
    var destination: MusicRoute?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title2.bold())
            Spacer()
            if let destination {
                NavigationLink(value: destination) {
                    Text("ui.common.view_all")
                        .font(.subheadline)
                }
            }
        }
    }
}
