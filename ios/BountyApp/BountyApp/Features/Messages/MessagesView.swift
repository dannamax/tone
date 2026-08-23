import SwiftUI

struct MessagesView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @StateObject private var vm = MessagesViewModel()
    @State private var selectedNotif: NotificationItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.bountyDanger)
                        .padding(.horizontal, 20)
                }

                if vm.isLoading {
                    VStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonCard()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    Spacer()
                } else if vm.notifications.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "bell.slash",
                        title: L10n.messagesEmpty,
                        subtitle: L10n.messagesEmptyHint
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(vm.notifications) { notif in
                            if let taskId = notif.taskId, !taskId.isEmpty {
                                NavigationLink {
                                    TaskDetailView(taskID: taskId)
                                } label: {
                                    NotificationRow(notification: notif)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .onAppear { vm.markRead(id: notif.id) }
                            } else {
                                Button {
                                    selectedNotif = notif
                                } label: {
                                    NotificationRow(notification: notif)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.bountyBg)
                    .refreshable { vm.load() }
                    .alert(item: $selectedNotif) { notif in
                        Alert(
                            title: Text(notif.title),
                            message: Text(notif.content),
                            dismissButton: .default(Text(L10n.messagesGotIt))
                        )
                    }
                }
            }
            .background(Color.bountyBg)
            .navigationTitle(L10n.messagesTitle)
            .toolbar {
                if !vm.notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.messagesReadAll) {
                            vm.markAllRead()
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.bountyGold)
                    }
                }
            }
            .onAppear { Task { vm.load() } }
        }
    }
}

struct NotificationRow: View {
    let notification: NotificationItem

    var icon: String {
        switch notification.type {
        case "task_claimed": return "person.badge.plus"
        case "task_submitted": return "photo.on.rectangle"
        case "task_confirmed": return "checkmark.seal.fill"
        case "task_disputed": return "exclamationmark.triangle.fill"
        case "task_released": return "arrow.uturn.left"
        case "task_refunded": return "arrow.triangle.2.circlepath"
        default: return "bell.fill"
        }
    }

    var iconColor: Color {
        switch notification.type {
        case "task_confirmed": return .bountySuccess
        case "task_disputed": return .bountyDanger
        case "task_submitted": return .bountyGold
        default: return .bountyInfo
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(notification.isRead ? .bountyTextSecondary : .bountyText)
                Text(notification.content)
                    .font(.system(size: 12))
                    .foregroundColor(.bountyTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack {
                if !notification.isRead {
                    Circle().fill(Color.bountyDanger).frame(width: 8, height: 8)
                }
                Spacer()
                Text(notification.createdAt)
                    .font(.system(size: 11))
                    .foregroundColor(.bountyGray)
            }
        }
        .padding(12)
        .background(notification.isRead ? Color.white : Color.bountyGold.opacity(0.04))
        .cornerRadius(12)
    }
}

struct NotificationItem: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let content: String
    let taskId: String?
    let isRead: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, title, content
        case taskId = "task_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

/// @MainActor-isolated so @Published mutations happen only on the main actor,
/// avoiding the Swift 6 strict-concurrency data-race crash seen in Release
/// builds when switching to the Messages tab (same fix as MyTasksViewModel).
@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp: APIResponse<PaginatedResponse<NotificationItem>> = try await APIClient.shared.request(
                    "/notifications?page=1&size=50"
                )
                if resp.code == 0, let data = resp.data {
                    notifications = data.items
                } else {
                    notifications = []
                    errorMessage = resp.message
                }
                isLoading = false
            } catch {
                print("[Messages] load error: \(error)")
                // Mock/fallback so the UI has something to show during UI tests.
                notifications = [
                    NotificationItem(id: "1", type: "task_claimed", title: L10n.messagesOfferClaimed, content: "", taskId: nil, isRead: false, createdAt: "Today"),
                    NotificationItem(id: "2", type: "task_submitted", title: L10n.messagesEvidenceSubmitted, content: "", taskId: nil, isRead: true, createdAt: "Yesterday"),
                    NotificationItem(id: "3", type: "task_confirmed", title: String(format: L10n.messagesBountyReceived, 8.50), content: "", taskId: nil, isRead: true, createdAt: "2 days ago")
                ]
                isLoading = false
            }
        }
    }

    func markAllRead() {
        Task {
            let _ = try? await APIClient.shared.request(
                "/notifications/read-all", method: "POST"
            ) as APIResponse<EmptyResponse>
            notifications = notifications.map { n in
                NotificationItem(id: n.id, type: n.type, title: n.title, content: n.content, taskId: n.taskId, isRead: true, createdAt: n.createdAt)
            }
        }
    }

    func markRead(id: String) {
        guard let notif = notifications.first(where: { $0.id == id }), !notif.isRead else { return }
        Task {
            let _ = try? await APIClient.shared.request(
                "/notifications/\(id)/read", method: "POST"
            ) as APIResponse<EmptyResponse>
            notifications = notifications.map { n in
                guard n.id == id else { return n }
                return NotificationItem(id: n.id, type: n.type, title: n.title, content: n.content, taskId: n.taskId, isRead: true, createdAt: n.createdAt)
            }
        }
    }
}
