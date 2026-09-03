import SwiftUI
import PhotosUI

// MARK: - Task Detail View

struct TaskDetailView: View {
    let taskID: String
    @EnvironmentObject var appState: AppState
    @ObservedObject private var lang = LanguageManager.shared
    @StateObject private var vm = TaskDetailViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showEditTask = false
    // Guideline 1.2: content reporting & blocking
    @State private var showReportAlert = false
    @State private var reportTargetType = "task" // task | user
    @State private var reportReason = ""
    @State private var showBlockConfirm = false

    private var isOwnTask: Bool {
        guard let task = vm.task, let cu = appState.currentUser else { return false }
        return task.publisherID == cu.id
    }

    private var isClaimer: Bool {
        guard let task = vm.task, appState.currentUser != nil else { return false }
        return task.status != "published" && !isOwnTask
    }

    var body: some View {
        VStack(spacing: 0) {
            // 消息对话区域
            if vm.isLoading {
                Spacer()
                ProgressView().padding()
                Spacer()
            } else if vm.task == nil && !vm.isLoading {
                EmptyStateView(icon: "doc.questionmark", title: L10n.taskNotFound, subtitle: L10n.taskNotFoundHint)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            taskHeaderCard
                            statusBanner
                            submissionSection
                            messagesSection
                        }
                        .padding(.bottom, 12)
                        .contentShape(Rectangle())
                        .onTapGesture { hideKeyboard() }
                    }
                    .onChange(of: vm.messages.count) { _ in
                        scrollToBottom(proxy)
                    }
                    .onAppear { scrollToBottom(proxy, animated: false) }
                }
            }

            // 底部操作区
            bottomBar
        }
        .background(Color.bountyBg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.taskDetailTitle).font(.system(size: 17, weight: .semibold))
            }
            // Guideline 1.2: report / block entry for third-party tasks
            if !isOwnTask, vm.task != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            reportTargetType = "task"
                            showReportAlert = true
                        } label: {
                            Label(L10n.reportTask, systemImage: "flag")
                        }
                        Button {
                            reportTargetType = "user"
                            showReportAlert = true
                        } label: {
                            Label(L10n.reportUser, systemImage: "person.crop.circle.badge.exclamationmark")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label(L10n.blockUser, systemImage: "hand.raised.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .medium))
                    }
                }
            }
        }
        .alert(L10n.reportTitle, isPresented: $showReportAlert) {
            TextField(L10n.reportReasonPlaceholder, text: $reportReason)
            Button(L10n.commonSend) {
                let reason = reportReason.trimmingCharacters(in: .whitespacesAndNewlines)
                let isTask = reportTargetType == "task"
                guard !reason.isEmpty, let task = vm.task else { return }
                let targetID = isTask ? taskID : (task.publisherID)
                vm.report(targetType: isTask ? "task" : "user", targetID: targetID, reason: reason) { msg in
                    appState.showToast(msg)
                }
                reportReason = ""
            }
            Button(L10n.commonCancel, role: .cancel) { reportReason = "" }
        } message: {
            Text(reportTargetType == "task" ? L10n.reportTaskHint : L10n.reportUserHint)
        }
        .confirmationDialog(L10n.blockUserConfirm, isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button(L10n.blockUser, role: .destructive) {
                guard let publisherID = vm.task?.publisherID else { return }
                vm.block(userID: publisherID) { msg in
                    appState.showToast(msg)
                    dismiss()
                }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        }
        .sheet(isPresented: $vm.showPhotoPicker) {
            PhotoPickerView(selectedImages: $vm.selectedImages, selectedCount: vm.selectedImages.count)
        }
        .sheet(isPresented: $vm.showChatPhotoPicker) {
            PhotoPickerView(selectedImages: $vm.pendingImages, selectedCount: vm.pendingImages.count)
        }
        .sheet(isPresented: $showEditTask, onDismiss: {
            vm.loadAll(taskID: taskID, currentUserID: appState.currentUser?.id ?? "")
        }) {
            if let t = vm.task {
                PublishView(editingTask: t)
            }
        }
        .onAppear { vm.loadAll(taskID: taskID, currentUserID: appState.currentUser?.id ?? "") }
    }

    // MARK: - Task Header

    private var taskHeaderCard: some View {
        Group {
            if let task = vm.task {
                VStack(spacing: 12) {
                    HStack {
                        BeansBadge(beans: task.bountyBeans, fontSize: 20)
                        Spacer()
                        StatusBadge(status: task.status)
                    }
                    Text(task.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.bountyText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.system(size: 14))
                            .foregroundColor(.bountyTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 16) {
                    Label(task.targetAddr.isEmpty ? L10n.taskNoLocation : task.targetAddr,
                          systemImage: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.bountyGray)
                        Label(AppLocale.radiusDisplay(task.radius), systemImage: "scope")
                            .font(.system(size: 12))
                            .foregroundColor(.bountyGray)
                        Label(String(format: L10n.taskTimeMin, task.timeLimit), systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.bountyGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        if let task = vm.task {
            let banner: (icon: String, text: String, color: Color) = {
                switch task.status {
                case "claimed":
                    return ("hourglass", L10n.format("task_claimed_banner", task.timeLimit), .bountyInfo)
                case "submitted":
                    if isOwnTask { return ("checkmark.circle", L10n.taskReceivedSubmit, .bountySuccess) }
                    else { return ("paperplane.fill", L10n.taskWaitReview, .bountyWarning) }
                case "completed":
                    return ("checkmark.seal.fill", L10n.taskCompletedPaid, .bountySuccess)
                case "disputed":
                    return ("exclamationmark.triangle.fill", L10n.taskDisputed, .bountyDanger)
                default:
                    return ("", "", .clear)
                }
            }()
            if !banner.text.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: banner.icon).foregroundColor(banner.color)
                    Text(banner.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(banner.color)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(banner.color.opacity(0.08))
                .padding(.horizontal, 16).padding(.top, 8)
            }
        }
    }

    // MARK: - Submission Section

    @ViewBuilder
    private var submissionSection: some View {
        // submitted 状态展示提交证据
        if let task = vm.task, task.status == "submitted" || task.status == "completed" || task.status == "disputed" {
            if let sub = vm.submission {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.taskEvidence).font(.system(size: 14, weight: .semibold)).foregroundColor(.bountyDark)

                    if !sub.note.isEmpty {
                        Text(sub.note).font(.system(size: 14)).foregroundColor(.bountyTextSecondary)
                    }

                    if !sub.photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sub.photos) { photo in
                                    AsyncImage(url: buildImageURL(photo.url)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.bountyGray.opacity(0.2)
                                    }
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // 发布人的审核按钮
                    if (task.status == "submitted" || task.status == "disputed") && isOwnTask {
                        reviewButtons
                    }
                    // 发布人编辑未被领取的任务
                    if task.status == "published" && isOwnTask {
                        Button {
                            showEditTask = true
                        } label: {
                            Label(L10n.taskEditTitle, systemImage: "pencil.circle")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .bountyButton(color: .bountyWarning)
                        .padding(.top, 4)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            } else if vm.isLoadingSubmission {
                HStack { ProgressView(); Text(L10n.loading).font(.system(size: 13)).foregroundColor(.bountyGray) }
                    .padding(16).frame(maxWidth: .infinity)
            } else {
                // 证据拉取失败也不能卡死审核流程：发布方仍可确认/要求补充
                VStack(spacing: 10) {
                    Text(L10n.taskEvidenceLoadFailed)
                        .font(.system(size: 13)).foregroundColor(.bountyGray)
                    if (task.status == "submitted" || task.status == "disputed") && isOwnTask {
                        reviewButtons
                    }
                }
                .padding(16).frame(maxWidth: .infinity)
            }
        }
    }

    /// 发布人审核操作（确认放款 / 要求补充证据）。
    /// 独立成子视图，确保证据加载失败时审核入口依然可用。
    /// disputed 状态下"要求补充"即撤销争议，任务回退 claimed 让接单人重新提交。
    @ViewBuilder
    private var reviewButtons: some View {
        HStack(spacing: 10) {
            if vm.task?.status != "disputed" {
                Button {
                    vm.confirmTask(taskID: taskID) { msg in
                        appState.showToast(msg)
                        appState.refreshMyTasksTrigger.toggle()
                        appState.refreshSquareTrigger.toggle()
                    }
                } label: {
                    if vm.isReviewing {
                        ProgressView().tint(.white)
                    } else {
                        Label(L10n.taskConfirmPass, systemImage: "checkmark.seal")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .bountyButton(color: .bountySuccess)
                .disabled(vm.isReviewing)
            }

            Button {
                vm.requestChanges(taskID: taskID, reason: "evidence_not_sufficient") { msg in
                    appState.showToast(msg)
                    appState.refreshMyTasksTrigger.toggle()
                }
            } label: {
                Label(L10n.taskRequestMore, systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .medium))
            }
            .bountyButton(color: .bountyWarning)
            .disabled(vm.isReviewing)
        }
        .padding(.top, 4)
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        VStack(spacing: 0) {
            Text(L10n.taskChatTitle).font(.system(size: 13, weight: .medium)).foregroundColor(.bountyGray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 6)

            if vm.messages.isEmpty && !vm.isLoadingMessages {
                Text(L10n.taskChatEmpty)
                    .font(.system(size: 13)).foregroundColor(.bountyGray)
                    .padding(.vertical, 20)
            }

            ForEach(vm.messages) { msg in
                MessageBubble(
                    message: msg,
                    isMine: msg.senderID == (appState.currentUser?.id ?? ""),
                    task: vm.task
                )
                .id(msg.id)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        if let task = vm.task {
            // published 状态且不是自己的任务 → 领取按钮
            if task.status == "published" && !isOwnTask {
                // 定向领取：计算用户与任务地点距离，超出领取围栏则置灰并提示
                let userLoc = CLLocation(latitude: appState.userLat, longitude: appState.userLng)
                let taskLoc = CLLocation(latitude: task.targetLat, longitude: task.targetLng)
                let distanceM = userLoc.distance(from: taskLoc)
                let inRange = distanceM <= Double(task.radius)
                let outOfRange = appState.userLat == 0 && appState.userLng == 0

                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        Spacer()
                        VStack(spacing: 4) {
                            Button {
                                vm.claimTask(taskID: taskID, lat: appState.userLat, lng: appState.userLng) { msg in
                                    appState.showToast(msg)
                                    appState.refreshSquareTrigger.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if vm.isClaiming {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: inRange ? "hand.raised.fill" : "location.slash.fill")
                                            .font(.system(size: 16))
                                    }
                                    Text(vm.isClaiming ? L10n.taskClaiming : (outOfRange ? L10n.claimNeedLocation : L10n.taskClaim))
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background((vm.isClaiming || !inRange || outOfRange) ? Color.bountyGold.opacity(0.4) : Color.bountyGold)
                                .cornerRadius(12)
                            }
                            .disabled(vm.isClaiming || !inRange || outOfRange)
                            if !inRange && !outOfRange {
                                Text(String(format: L10n.claimOutOfRange, Int(distanceM), task.radius))
                                    .font(.system(size: 11))
                                    .foregroundColor(.bountyDanger)
                            }
                            if outOfRange {
                                Text(L10n.claimNeedLocationHint)
                                    .font(.system(size: 11))
                                    .foregroundColor(.bountyTextSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                }
            }

            // claimed / submitted 状态 → 聊天 + 提交入口
            if (task.status == "claimed" || task.status == "submitted") {
            VStack(spacing: 0) {
                Divider()

                // 图片预览条
                if !vm.pendingImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.pendingImages.indices, id: \.self) { i in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: vm.pendingImages[i])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .cornerRadius(6)
                                    Button { vm.pendingImages.remove(at: i) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white).font(.system(size: 14))
                                            .background(Circle().fill(Color.black.opacity(0.5)))
                                    }.padding(1)
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 6)
                    }
                }

                HStack(spacing: 8) {
                    // 图片选择
                    Button { vm.showChatPhotoPicker = true } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                            .foregroundColor(.bountyGray)
                    }

                    // 文字输入
                    TextField(L10n.taskChatPlaceholder, text: $vm.inputText, axis: .vertical)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(18)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.bountyGray.opacity(0.3)))

                    // 提交完成凭证按钮（仅接单人且任务进行中显示）
                    if task.status == "claimed" && isClaimer {
                        Button {
                            vm.submitEvidenceFromChat(taskID: taskID) { msg in
                                appState.showToast(msg)
                            }
                        } label: {
                            if vm.isSubmitting {
                                ProgressView().tint(.bountySuccess)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.bountySuccess)
                            }
                        }
                        .disabled(vm.isSubmitting)
                    }

                    // 发送按钮
                    Button {
                        vm.sendMessage(taskID: taskID) { msg in
                            appState.showToast(msg)
                        }
                    } label: {
                        if vm.isSending {
                            ProgressView().tint(.bountyGold)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(
                                    vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    && vm.pendingImages.isEmpty ? .bountyGray : .bountyGold
                                )
                        }
                    }
                    .disabled(vm.isSending || (vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.pendingImages.isEmpty))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(Color.bountyBg)
        }
    }
    }

    // MARK: - Helpers

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let last = vm.messages.last?.id else { return }
        if animated {
            withAnimation { proxy.scrollTo(last, anchor: .bottom) }
        } else {
            proxy.scrollTo(last, anchor: .bottom)
        }
    }

    private func buildImageURL(_ path: String) -> URL? {
        resolveImageURL(path)
    }
}

// MARK: - 图片 URL 解析（全局 helper，消息气泡与证据图共用）

/// 把后端返回的图片路径解析为可加载的 URL：
/// - 绝对 http(s) URL（COS 生产）直接使用；
/// - 相对路径（本地存储 "/uploads/..."）拼到 APIClient 当前生效 origin，
///   保证与 API 请求同源（自动发现后的局域网地址 / 生产域名）。
func resolveImageURL(_ path: String) -> URL? {
    if path.hasPrefix("http") { return URL(string: path) }
    if path.hasPrefix("/uploads/") {
        return URL(string: APIClient.shared.currentOrigin + path)
    }
    return URL(string: path)
}

struct MessageBubble: View {
    let message: TaskMessage
    let isMine: Bool
    let task: TaskItem?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMine { Spacer(minLength: 50) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                // 发送者标签：角色 + 昵称（账户名）
                if !isMine {
                    let role = message.senderID == task?.publisherID ? L10n.taskSenderPub : L10n.taskSenderClaimer
                    let nick = message.senderNickname ?? ""
                    let label = nick.isEmpty ? role : "\(role) · \(nick)"
                    Text(label).font(.system(size: 11)).foregroundColor(.bountyGray)
                        .padding(.leading, 2)
                }

                // 图片
                if !message.imageURLs.isEmpty {
                    ForEach(message.imageURLs, id: \.self) { url in
                        AsyncImage(url: buildImageURL(url)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.bountyGray.opacity(0.2)
                        }
                        .frame(maxWidth: 200, maxHeight: 200)
                        .cornerRadius(10)
                    }
                }

                // 文字
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundColor(isMine ? .white : .bountyText)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(isMine ? Color.bountyInfo : Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                }

                // 时间
                Text(formatTime(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(.bountyGray)
                    .padding(.horizontal, 4)
            }

            if !isMine { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    private func buildImageURL(_ path: String) -> URL? {
        resolveImageURL(path)
    }

    private func formatTime(_ raw: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: raw) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        }
        // fallback
        let trimmed = String(raw.prefix(19)).replacingOccurrences(of: "T", with: " ")
        return trimmed.count >= 16 ? String(trimmed.suffix(5)) : raw
    }
}

// MARK: - Photo Picker

struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    var selectedCount: Int

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = max(1, 5 - selectedCount)
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        init(_ parent: PhotoPickerView) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                        if let uiImage = obj as? UIImage {
                            DispatchQueue.main.async {
                                self?.parent.selectedImages.append(uiImage)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - ViewModel

class TaskDetailViewModel: ObservableObject {
    @Published var task: TaskItem?
    @Published var isLoading = true
    @Published var messages: [TaskMessage] = []
    @Published var isLoadingMessages = false
    @Published var submission: Submission?
    @Published var isLoadingSubmission = false

    // 提交证据
    @Published var submitNote = ""
    @Published var selectedImages: [UIImage] = []

    // 对话输入
    @Published var inputText = ""
    @Published var pendingImages: [UIImage] = []
    @Published var isSending = false
    @Published var isSubmitting = false
    @Published var isReviewing = false
    @Published var isClaiming = false
    @Published var showPhotoPicker = false
    @Published var showChatPhotoPicker = false

    private var currentUserID = ""
    private var uploadedURLs: [String] = []

    func loadAll(taskID: String, currentUserID: String) {
        self.currentUserID = currentUserID
        // 消息独立并行加载，不影响主内容渲染
        loadMessages(taskID: taskID)

        // 先加载任务，等任务完成后如有提交记录则加载，全部完成后才渲染主内容
        Task { @MainActor in
            isLoading = true

            // 1. 加载任务
            do {
                let resp: APIResponse<TaskItem> = try await APIClient.shared.request("/tasks/\(taskID)")
                if resp.code == 0 { task = resp.data }
            } catch { print("[TaskDetail] loadTask error: \(error)") }

            // 2. 有提交记录时同步加载（保证渲染前数据到位）
            if let t = task, t.status == "submitted" || t.status == "completed" || t.status == "disputed" {
                isLoadingSubmission = true
                do {
                    let resp: APIResponse<Submission> = try await APIClient.shared.request("/tasks/\(taskID)/submission")
                    if resp.code == 0 { submission = resp.data }
                } catch { print("[TaskDetail] loadSubmission error: \(error)") }
                isLoadingSubmission = false
            }

            // 3. 全部就绪后才展示内容
            isLoading = false
        }
    }

    func loadTask(id: String) {
        Task { @MainActor in
            isLoading = true
            do {
                let resp: APIResponse<TaskItem> = try await APIClient.shared.request("/tasks/\(id)")
                if resp.code == 0 { task = resp.data }
            } catch { print("[TaskDetail] loadTask error: \(error)") }

            // 有提交记录时加载证据
            if let t = task, t.status == "submitted" || t.status == "completed" || t.status == "disputed" {
                isLoadingSubmission = true
                do {
                    let resp: APIResponse<Submission> = try await APIClient.shared.request("/tasks/\(id)/submission")
                    if resp.code == 0 { submission = resp.data }
                } catch { print("[TaskDetail] loadSubmission error: \(error)") }
                isLoadingSubmission = false
            }

            isLoading = false
        }
    }

    func loadSubmission(taskID: String) {
        Task { @MainActor in
            isLoadingSubmission = true
            do {
                let resp: APIResponse<Submission> = try await APIClient.shared.request("/tasks/\(taskID)/submission")
                if resp.code == 0 { submission = resp.data }
            } catch { print("[TaskDetail] loadSubmission error: \(error)") }
            isLoadingSubmission = false
        }
    }

    func loadMessages(taskID: String) {
        Task { @MainActor in
            isLoadingMessages = true
            do {
                let resp: APIResponse<PaginatedResponse<TaskMessage>> = try await APIClient.shared.request("/tasks/\(taskID)/messages")
                if resp.code == 0 { messages = resp.data?.items ?? [] }
            } catch { print("[TaskDetail] loadMessages error: \(error)") }
            isLoadingMessages = false
        }
    }

    // MARK: - Report & Block (Guideline 1.2 UGC)

    /// 举报任务或用户（targetType: "task" | "user"）
    func report(targetType: String, targetID: String, reason: String, onDone: @escaping (String) -> Void) {
        Task { @MainActor in
            do {
                let body: [String: Any] = ["target_type": targetType, "target_id": targetID, "reason": reason]
                let resp: APIResponse<String> = try await APIClient.shared.request(
                    "/reports", method: "POST", body: body
                )
                if resp.code == 0 {
                    onDone(L10n.reportSubmitted)
                } else {
                    onDone(resp.message.isEmpty ? L10n.taskSendFailRetry : resp.message)
                }
            } catch {
                onDone(error.localizedDescription)
            }
        }
    }

    /// 拉黑用户：双方互相不可见任务、不可领取、不可在任务内发消息。
    func block(userID: String, onDone: @escaping (String) -> Void) {
        Task { @MainActor in
            do {
                let resp: APIResponse<String> = try await APIClient.shared.request(
                    "/users/\(userID)/block", method: "POST", body: [String: Any]()
                )
                if resp.code == 0 {
                    onDone(L10n.userBlocked)
                } else {
                    onDone(resp.message.isEmpty ? L10n.taskSendFailRetry : resp.message)
                }
            } catch {
                onDone(error.localizedDescription)
            }
        }
    }

    // MARK: - Send Message (text + images)

    func sendMessage(taskID: String, onError: @escaping (String) -> Void) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImages = !pendingImages.isEmpty
        guard !text.isEmpty || hasImages else {
            onError(L10n.taskMsgEmpty)
            return
        }

        Task { @MainActor in
            isSending = true

            // 先上传图片
            var urls: [String] = []
            for image in pendingImages {
                if let data = image.jpegData(compressionQuality: 0.75) {
                    let b64 = data.base64EncodedString()
                    do {
                        let resp: APIResponse<UploadImageResponse> = try await APIClient.shared.request(
                            "/upload", method: "POST",
                            body: ["base64": b64, "name": "photo.jpg"]
                        )
                        if resp.code == 0, let u = resp.data { urls.append(u.url) }
                    } catch { print("[Upload] failed: \(error)") }
                }
            }

            // 发送消息
            var body: [String: Any] = ["content": text]
            if !urls.isEmpty { body["image_urls"] = urls }
            do {
                let resp: APIResponse<TaskMessage> = try await APIClient.shared.request(
                    "/tasks/\(taskID)/messages", method: "POST", body: body
                )
                if resp.code == 0 {
                    inputText = ""
                    pendingImages = []
                    loadMessages(taskID: taskID)
                } else {
                    let msg = resp.message.isEmpty ? L10n.taskSendFailRetry : resp.message
                    onError(msg)
                }
            } catch {
                onError(L10n.taskSendFailRetry)
            }
            isSending = false
        }
    }

    func submitEvidence(taskID: String, onError: @escaping (String) -> Void) {
        submitEvidence(taskID: taskID, note: submitNote, images: selectedImages, onError: onError)
    }

    /// 从聊天输入区提交完成凭证（UI 简化后的入口）
    func submitEvidenceFromChat(taskID: String, onError: @escaping (String) -> Void) {
        let note = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        submitEvidence(taskID: taskID, note: note, images: pendingImages) { msg in
            self.inputText = ""
            self.pendingImages = []
            onError(msg)
        }
    }

    private func submitEvidence(taskID: String, note: String, images: [UIImage], onError: @escaping (String) -> Void) {
        Task { @MainActor in
            isSubmitting = true

            // 上传图片
            var urls: [String] = []
            for image in images {
                if let data = image.jpegData(compressionQuality: 0.75) {
                    let b64 = data.base64EncodedString()
                    do {
                        let resp: APIResponse<UploadImageResponse> = try await APIClient.shared.request(
                            "/upload", method: "POST",
                            body: ["base64": b64, "name": "photo.jpg"]
                        )
                        if resp.code == 0, let u = resp.data { urls.append(u.url) }
                    } catch { print("[Upload] failed for submit: \(error)") }
                }
            }

            let photos: [[String: Any]] = urls.map { [
                "url": $0, "latitude": 0.0, "longitude": 0.0,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ] }

            let body: [String: Any] = [
                "task_id": taskID,
                "note": note,
                "photos": photos,
                "submit_lat": task?.targetLat ?? 0.0,
                "submit_lng": task?.targetLng ?? 0.0
            ]

            do {
                let resp: APIResponse<EmptyResponse> = try await APIClient.shared.request(
                    "/tasks/\(taskID)/submit", method: "POST", body: body
                )
                if resp.code == 0 {
                    submitNote = ""
                    selectedImages = []
                    loadTask(id: taskID)
                    loadMessages(taskID: taskID)
                    loadSubmission(taskID: taskID)
                    onError(L10n.taskSubmitSuccess)
                } else {
                    onError(resp.message.isEmpty ? L10n.taskSubmitFail : resp.message)
                }
            } catch {
                onError(L10n.taskSubmitFailNetwork)
            }
            isSubmitting = false
        }
    }

    func claimTask(taskID: String, lat: Double, lng: Double, onError: @escaping (String) -> Void) {
        Task { @MainActor in
            isClaiming = true
            do {
                let resp: APIResponse<EmptyResponse> = try await APIClient.shared.request(
                    "/tasks/\(taskID)/claim", method: "POST",
                    body: ["lat": lat, "lng": lng]
                )
                if resp.code == 0 {
                    loadTask(id: taskID)
                    loadMessages(taskID: taskID)
                    loadSubmission(taskID: taskID)
                } else {
                    onError(resp.message.isEmpty ? L10n.taskOpsFailShort : resp.message)
                }
            } catch {
                onError(L10n.taskOpsFailed)
            }
            isClaiming = false
        }
    }

    func confirmTask(taskID: String, onError: @escaping (String) -> Void) {
        Task { @MainActor in
            isReviewing = true
            do {
                let resp: APIResponse<EmptyResponse> = try await APIClient.shared.request(
                    "/tasks/\(taskID)/confirm", method: "POST"
                )
                if resp.code == 0 {
                    loadTask(id: taskID)
                    onError(L10n.taskConfirmPaid)
                } else {
                    onError(resp.message.isEmpty ? L10n.taskOpsFailShort : resp.message)
                }
            } catch {
                onError(L10n.taskOpsFailed)
            }
            isReviewing = false
        }
    }

    /// 发布人"要求补充证据"：任务回退 claimed，接单人可修改后重新提交。
    /// 注意不是 dispute——争议是独立的纠纷通道，不应被审核操作误触发。
    func requestChanges(taskID: String, reason: String, onError: @escaping (String) -> Void) {
        Task { @MainActor in
            isReviewing = true
            do {
                let resp: APIResponse<EmptyResponse> = try await APIClient.shared.request(
                    "/tasks/\(taskID)/request-changes", method: "POST",
                    body: ["reason": reason]
                )
                if resp.code == 0 {
                    loadTask(id: taskID)
                    onError(L10n.taskEvidenceRequested)
                } else {
                    onError(resp.message.isEmpty ? L10n.taskOpsFailShort : resp.message)
                }
            } catch {
                onError(L10n.taskOpsFailed)
            }
            isReviewing = false
        }
    }

}

