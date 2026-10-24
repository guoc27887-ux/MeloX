import SwiftUI

struct NeteaseMessageContactsView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library

    @State private var contacts: [NeteaseMessageContact] = []
    @State private var searchQuery = ""
    @State private var phase: LoadingPhase = .loading

    var body: some View {
        List(filteredContacts) { contact in
            NavigationLink(
                value: NeteasePrivateMessageRoute.conversation(contact)
            ) {
                HStack(spacing: 12) {
                    ArtworkImage(
                        url: contact.artworkURL,
                        cornerRadius: 1_000
                    )
                    .frame(width: 48, height: 48)
                    .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(contact.displayName)
                            .lineLimit(1)

                        if let signature = contact.signature?
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ),
                           !signature.isEmpty {
                            Text(signature)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
        .navigationTitle("ui.messages.start_private_message")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: "ui.messages.search_following")
        .overlay {
            switch phase {
            case .loading where contacts.isEmpty:
                ProgressView("ui.messages.loading_contacts")
            case .failed(let message) where contacts.isEmpty:
                ConnectionUnavailableView(message: message) {
                    Task { await load() }
                }
            case .loaded where filteredContacts.isEmpty:
                ContentUnavailableView(
                    searchQuery.isEmpty
                        ? L10n.string("ui.messages.no_contacts")
                        : L10n.string("ui.messages.contacts_not_found"),
                    systemImage: searchQuery.isEmpty
                        ? "person.2.slash"
                        : "magnifyingglass"
                )
            default:
                EmptyView()
            }
        }
        .task {
            await load()
        }
    }

    private var filteredContacts: [NeteaseMessageContact] {
        let query = searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else { return contacts }
        return contacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(query)
                || contact.nickname.localizedCaseInsensitiveContains(query)
        }
    }

    private func load() async {
        phase = .loading
        do {
            let userID: Int
            if let profileID = library.profile?.id {
                userID = profileID
            } else {
                userID = try await api.accountProfile().id
            }
            contacts = try await api.messageContacts(userID: userID)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
