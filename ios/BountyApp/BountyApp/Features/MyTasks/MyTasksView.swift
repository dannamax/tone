import SwiftUI

struct MyTasksView: View {
    @StateObject private var vm = MyTasksViewModel()
    @State private var selectedTab = 0
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text(L10n.myTasksPublished).tag(0)
                    Text(L10n.myTasksClaimed).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if vm.isLoading {
                    VStack(spacing: 12) { SkeletonCard(); SkeletonCard() }
                        .padding(.horizontal, 20)
                    Spacer()
                } else if vm.tasks.isEmpty {
                    VStack(spacing: 8) {
                        EmptyStateView(
                            icon: "tray",
                            title: selectedTab == 0 ? L10n.myTasksEmptyPub : L10n.myTasksEmptyClaimed,
                            subtitle: vm.errorMessage ?? L10n.myTasksGoSquare
                        )
                        if vm.errorMessage != nil {
                            Button(L10n.myTasksReload) {
                                selectedTab == 0 ? vm.loadPublished() : vm.loadClaimed()
                            }
                            .foregroundColor(.bountyGold)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.tasks) { task in
                                VStack(spacing: 0) {
                                    NavigationLink {
                                        TaskDetailView(taskID: task.id)
                                    } label: {
                                        TaskCardView(task: task)
                                    }
                                    .buttonStyle(.plain)

                                    if task.status == "pending" {
                                        Button(action: { vm.activateTask(task) }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.up.circle.fill")
                                                Text(L10n.myTasksPublishNow)
                                            }
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.orange)
                                            .cornerRadius(8)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.bottom, 10)
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                }
            }
            .background(Color.bountyBg)
        .navigationTitle(L10n.myTasksTitle)
        .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if let toast = vm.activateToast {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(20)
                            .padding(.bottom, 40)
                    }
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            vm.activateToast = nil
                        }
                    }
                }
            }
            .onAppear {
                print("[MyTasks] onAppear currentUserID: \(appState.currentUser?.id ?? "nil"), email: \(appState.currentUser?.email ?? "nil")")
                selectedTab == 0 ? vm.loadPublished() : vm.loadClaimed()
            }
            .onChange(of: selectedTab) { tab in
                tab == 0 ? vm.loadPublished() : vm.loadClaimed()
            }
            .onChange(of: appState.refreshMyTasksTrigger) { _ in
                print("[MyTasks] refresh trigger currentUserID: \(appState.currentUser?.id ?? "nil")")
                selectedTab == 0 ? vm.loadPublished() : vm.loadClaimed()
            }
        }
    }
}

/// @MainActor-isolated so @Published mutations happen only on the main actor,
/// avoiding the Swift 6 strict-concurrency data-race crash seen in Release
/// builds when loadPublished/loadClaimed raced with their inner Tasks.
@MainActor
final class MyTasksViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activateToast: String?

    func loadPublished() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp: APIResponse<PaginatedResponse<TaskItem>> = try await APIClient.shared.request("/tasks/mine?tab=published&page=1&size=20")
                if resp.code == 0 {
                    tasks = resp.data?.items ?? []
                } else {
                    tasks = []
                    errorMessage = resp.message
                }
                isLoading = false
                print("[MyTasks] loadPublished success, count: \(tasks.count)")
            } catch {
                print("[MyTasks] loadPublished error: \(error)")
                isLoading = false
                errorMessage = L10n.myTasksLoadFailed + ": \(error.localizedDescription)"
            }
        }
    }

    func loadClaimed() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp: APIResponse<PaginatedResponse<TaskItem>> = try await APIClient.shared.request("/tasks/mine?tab=claimed&page=1&size=20")
                if resp.code == 0 {
                    tasks = resp.data?.items ?? []
                } else {
                    tasks = []
                    errorMessage = resp.message
                }
                isLoading = false
                print("[MyTasks] loadClaimed success, count: \(tasks.count)")
            } catch {
                print("[MyTasks] loadClaimed error: \(error)")
                isLoading = false
                errorMessage = L10n.myTasksLoadFailed + ": \(error.localizedDescription)"
            }
        }
    }

    func activateTask(_ task: TaskItem) {
        Task {
            activateToast = nil
            do {
                let resp: APIResponse<EmptyResponse> = try await APIClient.shared.request(
                    "/tasks/\(task.id)/activate", method: "POST"
                )
                if resp.code == 0 {
                    activateToast = L10n.myTasksPublishedToast
                    loadPublished()
                } else {
                    activateToast = resp.message.isEmpty ? L10n.myTasksPublishFailed : resp.message
                }
            } catch {
                activateToast = L10n.myTasksPublishFailed
            }
        }
    }
}
