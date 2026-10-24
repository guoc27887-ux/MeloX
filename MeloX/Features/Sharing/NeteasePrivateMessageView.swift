import SwiftUI

struct NeteasePrivateMessageView: View {
    let resource: NeteaseShareResource

    @Environment(\.dismiss) private var dismiss
    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library

    @State private var contacts: [NeteaseMessageContact] = []
    @State private var selectedContactIDs: Set<Int> = []
    @State private var message = ""
    @State private var searchQuery = ""
    @State private var phase: LoadingPhase = .loading
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("ui.messages.private_message_content") {
                NeteaseShareResourcePreview(resource: resource)

                TextField(
                    "ui.messages.optional_note",
                    text: $message,
                    axis: .vertical
                )
                .lineLimit(2...5)
            }

            Section {
                contactsContent
            } header: {
                HStack {
                    Text("ui.messages.recipients")
                    Spacer()
                    if !selectedContactIDs.isEmpty {
                        Text(L10n.format("ui.messages.selected_recipient_count", selectedContactIDs.count))
                    }
                }
            }
        }
        .navigationTitle("ui.sharing.netease_private_message")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: "ui.messages.search_following")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("ui.common.cancel") {
                    dismiss()
                }
                .disabled(isSending)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("ui.common.send")
                    }
                }
                .disabled(selectedContactIDs.isEmpty || isSending)
            }
        }
        .interactiveDismissDisabled(isSending)
        .task {
            await loadContacts()
        }
        .alert(
            "ui.messages.private_send_failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? L10n.string("ui.error.netease_operation_incomplete"))
        }
    }

    @ViewBuilder
    private var contactsContent: some View {
        switch phase {
        case .loading:
            HStack {
                Spacer()
                ProgressView("ui.messages.loading_contacts")
                Spacer()
            }
            .listRowBackground(Color.clear)
        case .failed(let message):
            ContentUnavailableView {
                Label("ui.messages.contacts_load_failed", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("ui.common.retry") {
                    Task { await loadContacts() }
                }
            }
            .listRowBackground(Color.clear)
        case .loaded:
            if filteredContacts.isEmpty {
                ContentUnavailableView(
                    searchQuery.isEmpty
                        ? L10n.string("ui.messages.no_contacts")
                        : L10n.string("ui.messages.contacts_not_found"),
                    systemImage: searchQuery.isEmpty
                        ? "person.2.slash"
                        : "magnifyingglass"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredContacts) { contact in
                    Button {
                        toggleSelection(for: contact)
                    } label: {
                        contactRow(contact)
                    }
                    .buttonStyle(.plain)
                }
            }
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

    private func contactRow(_ contact: NeteaseMessageContact) -> some View {
        HStack(spacing: 12) {
            ArtworkImage(url: contact.artworkURL, cornerRadius: 1_000)
                .frame(width: 44, height: 44)
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let signature = contact.signature?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !signature.isEmpty {
                    Text(signature)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(
                systemName: selectedContactIDs.contains(contact.id)
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .font(.title3)
            .foregroundStyle(
                selectedContactIDs.contains(contact.id)
                    ? Color.accentColor
                    : Color.secondary
            )
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(
            selectedContactIDs.contains(contact.id) ? .isSelected : []
        )
    }

    private func toggleSelection(for contact: NeteaseMessageContact) {
        if selectedContactIDs.contains(contact.id) {
            selectedContactIDs.remove(contact.id)
        } else {
            selectedContactIDs.insert(contact.id)
        }
    }

    private func loadContacts() async {
        guard phase != .loading || contacts.isEmpty else { return }
        phase = .loading

        do {
            let userID: Int
            if let profileID = library.profile?.id {
                userID = profileID
            } else {
                guard library.isLoggedIn else {
                    throw APIError.notLoggedIn
                }
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

    private func send() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        do {
            try await api.sendPrivateMessage(
                resource,
                to: Array(selectedContactIDs),
                message: message.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            )
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
