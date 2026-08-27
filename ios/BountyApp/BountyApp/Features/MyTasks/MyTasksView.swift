import SwiftUI

struct MyTasksView: View {
    @StateObject private var vm = MyTasksViewModel()
    @ObservedObject private var lang = LanguageManager.shared
    @State private var selectedTab = 0
    // 任务管理模式：仅"我发布的" tab 支持，多选后批量删除
    @State private var isManaging = false
    @State private var selectedIDs: Set<String> = []
    @State private var showDeleteConfirm = false
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
                                taskRow(task)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, isManaging ? 90 : 12)
                    }
                }
            }
            .background(Color.bountyBg)
            // 管理模式底部工具栏（全选 / 删除所选）
            .safeAreaInset(edge: .bottom) {
                if isManaging && selectedTab == 0 && !vm.tasks.isEmpty {
                    manageBar
                }
            }
        .navigationTitle(L10n.myTasksTitle)
        .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 仅"我发布的" tab 且列表非空时提供管理入口
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 0 && !vm.tasks.isEmpty {
                        Button(isManaging ? L10n.myTasksDone : L10n.myTasksManage) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isManaging.toggle()
                                selectedIDs.removeAll()
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.bountyGold)
                    }
                }
            }
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
            // 批量删除确认弹窗
            .alert(L10n.myTasksDeleteConfirmTitle, isPresented: $showDeleteConfirm) {
                Button(L10n.myTasksDeleteConfirmAction, role: .destructive) {
                    deleteSelected()
                }
                Button(L10n.myTasksDeleteConfirmCancel, role: .cancel) {}
            } message: {
                Text(String(format: L10n.myTasksDeleteConfirmMsg, selectedIDs.count))
            }
            .onAppear {
                print("[MyTasks] onAppear currentUserID: \(appState.currentUser?.id ?? "nil"), email: \(appState.currentUser?.email ?? "nil")")
                selectedTab == 0 ? vm.loadPublished() : vm.loadClaimed()
            }
            .onChange(of: selectedTab) { tab in
                isManaging = false
                selectedIDs.removeAll()
                tab == 0 ? vm.loadPublished() : vm.loadClaimed()
            }
            .onChange(of: appState.refreshMyTasksTrigger) { _ in
                print("[MyTasks] refresh trigger currentUserID: \(appState.currentUser?.id ?? "nil")")
                selectedTab == 0 ? vm.loadPublished() : vm.loadClaimed()
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func taskRow(_ task: TaskItem) -> some View {
        if isManaging && selectedTab == 0 {
            // 管理模式：整行点击切换选中，不进入详情
            Button {
                toggleSelection(task.id)
            } label: {
                HStack(spacing: 12) {
                    selectionCircle(isSelected: selectedIDs.contains(task.id))
                    TaskCardView(task: task)
                        .opacity(selectedIDs.contains(task.id) ? 1.0 : 0.72)
                }
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 0) {
                NavigationLink {
                    TaskDetailView(taskID: task.id)
                } label: {
                    TaskCardView(task: task)
                }
                .buttonStyle(.plain)
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    private func selectionCircle(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.bountyGold : Color.gray.opacity(0.5), lineWidth: 1.5)
                .frame(width: 24, height: 24)
            if isSelected {
                Circle()
                    .fill(Color.bountyGold)
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    // MARK: - Bottom manage bar

    @ViewBuilder
    private var manageBar: some View {
        HStack(spacing: 12) {
            Button {
                if selectedIDs.count == vm.tasks.count {
                    selectedIDs.removeAll()
                } else {
                    selectedIDs = Set(vm.tasks.map { $0.id })
                }
            } label: {
                Text(selectedIDs.count == vm.tasks.count ? L10n.myTasksDeselectAll : L10n.myTasksSelectAll)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.bountyText)
            }

            Spacer()

            Button {
                showDeleteConfirm = true
            } label: {
                Label(
                    String(format: L10n.myTasksDeleteSelected, selectedIDs.count),
                    systemImage: "trash"
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(selectedIDs.isEmpty ? Color.gray.opacity(0.5) : Color.bountyDanger)
                .cornerRadius(10)
            }
            .disabled(selectedIDs.isEmpty || vm.isDeleting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.4) }
    }

    // MARK: - Delete

    private func deleteSelected() {
        let ids = Array(selectedIDs)
        guard !ids.isEmpty else { return }
        vm.batchDelete(taskIDs: ids) { [weak vm] toastMsg in
            guard let vm = vm else { return }
            vm.activateToast = toastMsg
            // 刷新列表与金豆余额（未认领任务删除时后端会退豆）
            appState.refreshMyTasksTrigger.toggle()
            selectedIDs.removeAll()
            if vm.tasks.isEmpty {
                withAnimation { isManaging = false }
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
    @Published var isDeleting = false

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

    // MARK: - Batch delete

    func batchDelete(taskIDs: [String], onDone: @escaping (String) -> Void) {
        isDeleting = true
        Task {
            var toastMsg: String
            do {
                let resp: APIResponse<BatchDeleteResponse> = try await APIClient.shared.request(
                    "/tasks/delete-batch",
                    method: "POST",
                    body: ["task_ids": taskIDs]
                )
                if resp.code == 0, let data = resp.data {
                    if data.skipped.isEmpty {
                        toastMsg = String(format: L10n.myTasksDeletedFmt, data.deleted.count)
                    } else {
                        toastMsg = String(
                            format: L10n.myTasksDeletedSkippedFmt,
                            data.deleted.count, data.skipped.count
                        )
                    }
                } else {
                    toastMsg = resp.message.isEmpty ? L10n.myTasksDeleteFailed : resp.message
                }
            } catch {
                print("[MyTasks] batchDelete error: \(error)")
                toastMsg = L10n.myTasksDeleteFailed
            }
            isDeleting = false
            onDone(toastMsg)
        }
    }
}

/// 批量删除接口响应：deleted 为已删除任务 id；refunded 为其中删除时自动退豆的
/// 未认领任务数；skipped 为因进行中被跳过的任务及原因。
struct BatchDeleteResponse: Decodable {
    struct SkippedTask: Decodable {
        let taskID: String
        let reason: String

        enum CodingKeys: String, CodingKey {
            case taskID = "task_id"
            case reason
        }
    }

    let deleted: [String]
    let refunded: Int
    let skipped: [SkippedTask]
}
