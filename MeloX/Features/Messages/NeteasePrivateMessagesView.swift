import SwiftUI

enum NeteasePrivateMessageRoute: Hashable {
    case contacts
    case conversation(NeteaseMessageContact)
}

struct NeteasePrivateMessagesView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library

    @State private var conversations: [NeteasePrivateConversation] = []
    @State private var currentUserID = 0
    @State private var phase: LoadingPhase = .loading

    var body: some View {
        List {
            ForEach(conversations) { conversation in
                let contact = conversation.participant(
                    currentUserID: currentUserID
                )
                NavigationLink(
                    value: NeteasePrivateMessageRoute.conversation(contact)
                ) {
                    conversationRow(conversation, contact: contact)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("ui.messages.private.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: NeteasePrivateMessageRoute.contacts) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("ui.messages.start_private_message")
            }
        }
        .refreshable {
            await load()
        }
        .overlay {
            switch phase {
            case .loading where conversations.isEmpty:
                ProgressView("ui.messages.loading_private_messages")
            case .failed(let message) where conversations.isEmpty:
                ConnectionUnavailableView(message: message) {
                    Task { await load() }
                }
            case .loaded where conversations.isEmpty:
                ContentUnavailableView {
                    Label("ui.messages.empty", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("ui.messages.empty.message")
                } actions: {
                    NavigationLink(
                        "ui.messages.start_private_message",
                        value: NeteasePrivateMessageRoute.contacts
                    )
                    .buttonStyle(.borderedProminent)
                }
            default:
                EmptyView()
            }
        }
        .navigationDestination(for: NeteasePrivateMessageRoute.self) { route in
            switch route {
            case .contacts:
                NeteaseMessageContactsView()
            case .conversation(let contact):
                NeteaseConversationView(contact: contact) {
                    // 只有历史接口成功返回后才清除本地角标。首次历史
                    // 请求会同时在网易云服务端完成已读上报。
                    clearUnreadCount(for: contact.id)
                }
                .onDisappear {
                    Task {
                        await load()
                    }
                }
            }
        }
        .task {
            await load()
        }
    }

    private func conversationRow(
        _ conversation: NeteasePrivateConversation,
        contact: NeteaseMessageContact
    ) -> some View {
        HStack(spacing: 12) {
            ArtworkImage(url: contact.artworkURL, cornerRadius: 1_000)
                .frame(width: 52, height: 52)
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(contact.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if conversation.lastMessageTime > 0 {
                        Text(formattedTime(conversation.lastMessageTime))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack {
                    Text(conversation.lastMessage.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text(
                            conversation.unreadCount.formatted(
                                .number.locale(L10n.locale)
                            )
                        )
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: .capsule)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedTime(_ milliseconds: Int64) -> String {
        let date = Date(
            timeIntervalSince1970: TimeInterval(milliseconds) / 1_000
        )
        if Calendar.current.isDateInToday(date) {
            return date.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened)
                    .locale(L10n.locale)
            )
        }
        return date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(L10n.locale)
        )
    }

    private func clearUnreadCount(for contactID: Int) {
        guard let index = conversationIndex(for: contactID) else { return }
        conversations[index].unreadCount = 0
    }

    private func conversationIndex(for contactID: Int) -> Int? {
        conversations.firstIndex { conversation in
            conversation.participant(currentUserID: currentUserID).id == contactID
        }
    }

    private func load() async {
        phase = .loading
        do {
            if let profileID = library.profile?.id {
                currentUserID = profileID
            } else {
                currentUserID = try await api.accountProfile().id
            }
            conversations = try await api.privateMessageConversations()
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
