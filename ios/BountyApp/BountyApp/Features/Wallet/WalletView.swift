import SwiftUI

struct WalletView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @StateObject private var vm = WalletViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showPackages = false
    @State private var showRewardsComingSoon = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 金豆余额主卡片
                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Text(L10n.beansBalanceTitle)
                                .font(.system(size: 13))
                                .foregroundColor(.bountyTextSecondary)
                            HStack(spacing: 6) {
                                Image(systemName: "circle.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.bountyGold)
                                Text("\(vm.beansTotal)")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundColor(.bountyText)
                            }
                            Text(String(format: L10n.beansBreakdownFmt, vm.beansPurchased, vm.beansEarned))
                                .font(.system(size: 12))
                                .foregroundColor(.bountyGray)
                        }
                        .padding(.top, 12)

                        Button {
                            showPackages = true
                        } label: {
                            Text(L10n.beansBuyButton)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.bountyGold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)

                    // 奖励中心 · 即将上线（金豆用途扩展，不含提现承诺）
                    Button {
                        showRewardsComingSoon = true
                    } label: {
                        HStack {
                            Image(systemName: "gift.fill")
                                .foregroundColor(.bountyGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.rewardsCenterTitle)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.bountyText)
                                Text(L10n.rewardsCenterSubtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.bountyTextSecondary)
                            }
                            Spacer()
                            Text(L10n.rewardsComingSoon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.bountyGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.bountyGold.opacity(0.12)))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    if vm.isPurchasing {
                        ProgressView(L10n.quotaPurchasing)
                            .padding()
                    }
                    if let err = vm.loadError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.bountyDanger)
                            .padding(.horizontal, 8)
                    }

                    VStack(spacing: 0) {
                        NavigationLink {
                            TransactionListView()
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundColor(.bountyText)
                                Text(L10n.walletTransactions)
                                    .foregroundColor(.bountyText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.bountyGray)
                            }
                            .font(.system(size: 15))
                            .padding(16)
                            .background(Color.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color.bountyBg)
            .navigationTitle(L10n.walletTitle)
        }
        .sheet(isPresented: $showPackages) {
            QuotaPackagesSheet(vm: vm)
        }
        .sheet(isPresented: $showRewardsComingSoon) {
            RewardsCenterSheet(earned: vm.beansEarned, completed: vm.completedTasks)
        }
        .onAppear {
            vm.load()
            appState.refreshCurrentUser()
        }
    }
}

/// 奖励中心说明弹窗（V1：仅兑换规则预告 + 双进度展示，不提供真实兑换）
/// 合规要点：
/// 1. 只预告 earned 豆参与兑换（purchased 不参与）——与 IAP 隔离，防审核判定闭环套利；
/// 2. 双维门槛：已确认任务 ≥ 50 个（主门槛，工作量维度）且 earned ≥ 50 豆（最低累计
///    报酬下限；数学上被 50 任务蕴含——最低 5 象任务 × 50 = 250 豆，为防御性冗余条件）；
/// 3. 不承诺上线时间与具体比例（"Final rules will be published at launch"）；
/// 4. 全程用 rewards/redemption 措辞，不用 cash out/withdraw money。
struct RewardsCenterSheet: View {
    @ObservedObject private var lang = LanguageManager.shared
    let earned: Int
    let completed: Int
    @Environment(\.dismiss) private var dismiss

    private let beanThreshold = 50
    private let taskThreshold = 50

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 进度卡片（双门槛）
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.rewardsProgressTitle)
                            .font(.system(size: 13))
                            .foregroundColor(.bountyTextSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(earned)")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.bountyText)
                            Text("/ \(beanThreshold) \(L10n.walletBeansSuffix)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.bountyGray)
                            Spacer()
                            Text(L10n.rewardsComingSoon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.bountyGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.bountyGold.opacity(0.12)))
                        }
                        ProgressView(value: Double(min(earned, beanThreshold)), total: Double(beanThreshold))
                            .tint(.bountyGold)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(completed)")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.bountyText)
                            Text("/ \(taskThreshold) \(L10n.rewardsTasksSuffix)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.bountyGray)
                        }
                        .padding(.top, 4)
                        ProgressView(value: Double(min(completed, taskThreshold)), total: Double(taskThreshold))
                            .tint(.bountySuccess)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(14)

                    // 兑换规则预告
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.rewardsRulesTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.bountyText)
                        ruleRow(icon: "checkmark.circle.fill", color: .bountySuccess, text: L10n.rewardsRuleEarnedOnly)
                        ruleRow(icon: "gift.fill", color: .bountyGold, text: L10n.rewardsRuleThreshold)
                        ruleRow(icon: "creditcard.fill", color: .bountyInfo, text: L10n.rewardsRuleOptions)
                        ruleRow(icon: "person.2.fill", color: .bountyGray, text: L10n.rewardsRuleNoTransfer)
                        ruleRow(icon: "doc.text.fill", color: .bountyGray, text: L10n.rewardsRuleFinalNote)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(14)
                }
                .padding(20)
            }
            .background(Color.bountyBg)
            .navigationTitle(L10n.rewardsCenterTitle)
            .navigationBarItems(trailing: Button(L10n.commonClose) { dismiss() })
        }
    }

    private func ruleRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.bountyText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 额度套餐选择面板
struct QuotaPackagesSheet: View {
    @ObservedObject private var lang = LanguageManager.shared
    @ObservedObject var vm: WalletViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    if vm.packages.isEmpty && !vm.isPurchasing {
                        Text(L10n.quotaLoading)
                            .foregroundColor(.bountyGray)
                            .padding(.top, 40)
                    }
                    ForEach(vm.packages) { pkg in
                        Button {
                            Task {
                                await vm.purchase(pkg)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(pkg.localizedBeans)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.bountyText)
                                    Text(pkg.name)
                                        .font(.system(size: 13))
                                        .foregroundColor(.bountyTextSecondary)
                                }
                                Spacer()
                                Text(pkg.localizedPrice)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.bountyGold)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius:  14)
                                    .stroke(Color.bountyGold.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .disabled(vm.isPurchasing)
                    }

                    // 恢复购买（App Store 3.1.1 合规）：补齐付款成功但入账中断的订单
                    Button {
                        Task { await vm.restorePurchases() }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.isRestoring {
                                ProgressView().tint(.bountyGray)
                            }
                            Text(L10n.walletRestorePurchases)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.bountyInfo)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .disabled(vm.isPurchasing || vm.isRestoring)

                    if let msg = vm.restoreMessage {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(.bountyTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .navigationTitle(L10n.quotaPackagesTitle)
            .navigationBarItems(trailing: Button(L10n.commonClose) { dismiss() })
        }
    }
}

class WalletViewModel: ObservableObject {
    @Published var beansTotal: Int = 0
    @Published var beansPurchased: Int = 0
    @Published var beansEarned: Int = 0
    @Published var completedTasks: Int = 0
    @Published var packages: [QuotaPackage] = []
    @Published var isPurchasing = false
    @Published var isRestoring = false
    @Published var restoreMessage: String?
    @Published var loadError: String?

    func load() {
        Task {
            await MainActor.run { /* loading */ }
            do {
                let resp: APIResponse<WalletData> = try await APIClient.shared.request("/wallet")
                await MainActor.run {
                    if resp.code == 0, let data = resp.data {
                        self.beansPurchased = data.beansPurchased
                        self.beansEarned = data.beansEarned
                        self.beansTotal = data.beansTotal
                        self.completedTasks = data.completedTasks ?? 0
                        self.loadError = nil
                    } else {
                        self.loadError = resp.message.isEmpty ? L10n.walletLoadFailed : resp.message
                    }
                }
                await fetchPackages()
            } catch {
                await MainActor.run {
                    self.loadError = (error as? APIError)?.friendlyMessage ?? L10n.networkError
                }
            }
        }
    }

    func fetchPackages() async {
        do {
            let resp: APIResponse<[QuotaPackage]> = try await APIClient.shared.request(
                "/wallet/quota-packages",
                method: "GET"
            )
            await MainActor.run {
                if resp.code == 0, let list = resp.data {
                    self.packages = list
                }
            }
        } catch {
            // 套餐拉取失败不阻塞钱包展示
        }
    }

    /// 购买套餐：先创建后端订单，再走 StoreKit 支付，最后后端确认发放额度
    func purchase(_ pkg: QuotaPackage) async {
        await MainActor.run { isPurchasing = true; loadError = nil }
        do {
            // 1. 创建订单（channel=apple）
            let createResp: APIResponse<RechargeOrder> = try await APIClient.shared.request(
                "/wallet/quota/order",
                method: "POST",
                body: ["package_id": pkg.id, "channel": "apple"]
            )
            guard let order = createResp.data else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: createResp.message])
            }
            // 2. StoreKit 支付（商品 SKU 与套餐 ID 一致）
            _ = try await StoreKitManager.shared.purchase(productSKU: pkg.appleProductID, orderID: order.id)
            // 3. 后端已确认并放量，刷新钱包
            await load()
            await MainActor.run { isPurchasing = false }
        } catch {
            await MainActor.run {
                isPurchasing = false
                loadError = error.localizedDescription
            }
        }
    }

    /// 恢复购买：上传历史交易给后端幂等补发，展示结果
    func restorePurchases() async {
        await MainActor.run { isRestoring = true; restoreMessage = nil; loadError = nil }
        do {
            let result = try await StoreKitManager.shared.restorePurchases()
            await load()
            await MainActor.run {
                isRestoring = false
                if result.restored > 0 {
                    restoreMessage = String(format: L10n.walletRestoredFmt, result.restored)
                } else if result.already > 0 {
                    restoreMessage = L10n.walletRestoreAlready
                } else {
                    restoreMessage = L10n.walletRestoreNothing
                }
            }
        } catch {
            await MainActor.run {
                isRestoring = false
                restoreMessage = (error as? APIError)?.friendlyMessage ?? L10n.walletRestoreFailed
            }
        }
    }
}

/// 金豆流水（后端 /wallet/transactions 返回，对应 model.Transaction）
struct TransactionItem: Codable, Identifiable {
    let id: String
    let taskID: String?
    let type: String
    let status: String
    let remark: String?
    let beansDelta: Int
    let fromUserID: String?
    let toUserID: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case status
        case remark
        case createdAt = "created_at"
        case taskID = "task_id"
        case beansDelta = "beans_delta"
        case fromUserID = "from_user_id"
        case toUserID = "to_user_id"
    }

    /// 流水视角：同一笔转账记录，付款方与收款方看到的金额方向相反。
    enum Perspective {
        case income      // 收款：+N 绿色
        case expense     // 支出：-N 红色
        case transferOut // 赏金放款（from 视角的 bean_reward）：余额不变，中性显示
    }

    func perspective(for currentUserID: String?) -> Perspective {
        if let to = toUserID, to == currentUserID, beansDelta >= 0 { return .income }
        if let from = fromUserID, from == currentUserID, type == "bean_reward" { return .transferOut }
        return beansDelta >= 0 ? .income : .expense
    }

    func beansText(for currentUserID: String?) -> String {
        switch perspective(for: currentUserID) {
        case .income: return "+\(beansDelta)"
        case .expense: return "\(beansDelta)"
        case .transferOut: return "→"
        }
    }

    func isIncome(for currentUserID: String?) -> Bool {
        perspective(for: currentUserID) == .income
    }

    /// 展示标题：from 视角的 reward 换成支付语义（remark 里的 "earned" 文案不适用于付款方）
    func displayTitle(for currentUserID: String?) -> String {
        if perspective(for: currentUserID) == .transferOut { return L10n.walletTxBountyPaid }
        return remark?.isEmpty == false ? remark! : type
    }

    var icon: String {
        switch type {
        case "bean_spend": return "arrow.up.circle"
        case "bean_reward": return "checkmark.seal"
        case "bean_buy": return "plus.circle"
        case "bean_refund": return "arrow.uturn.backward.circle"
        case "bean_grant": return "gift"
        default: return "list.bullet.circle"
        }
    }
}

@MainActor
final class TransactionListViewModel: ObservableObject {
    @Published var items: [TransactionItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let resp: APIResponse<PaginatedResponse<TransactionItem>> = try await APIClient.shared.request(
                    "/wallet/transactions?page=1&size=50"
                )
                if resp.code == 0 {
                    items = resp.data?.items ?? []
                } else {
                    errorMessage = resp.message
                }
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// 交易流水页：读取真实金豆账本（/wallet/transactions），
/// 按 beans_delta 展示每笔入账/扣减；流水为账本，不随任务删除而消失。
struct TransactionListView: View {
    @StateObject private var vm = TransactionListViewModel()
    @ObservedObject private var lang = LanguageManager.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                VStack(spacing: 12) { SkeletonCard(); SkeletonCard() }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if vm.items.isEmpty {
                VStack(spacing: 8) {
                    EmptyStateView(
                        icon: "list.bullet.rectangle",
                        title: L10n.walletTxEmptyTitle,
                        subtitle: vm.errorMessage ?? L10n.walletTxEmptySubtitle
                    )
                    if vm.errorMessage != nil {
                        Button(L10n.myTasksReload) { vm.load() }
                            .foregroundColor(.bountyGold)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.items) { tx in
                            TransactionRow(item: tx, currentUserID: appState.currentUser?.id)
                            Divider().padding(.leading, 60)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
        }
        .background(Color.bountyBg)
        .navigationTitle(L10n.walletTransactions)
        .onAppear { vm.load() }
    }
}

private struct TransactionRow: View {
    let item: TransactionItem
    var currentUserID: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 20))
                .foregroundColor(item.isIncome(for: currentUserID) ? .bountySuccess : (item.perspective(for: currentUserID) == .transferOut ? .bountyTextSecondary : .bountyDanger))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle(for: currentUserID))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.bountyText)
                    .lineLimit(2)
                Text(item.createdAt.iso8601TimeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(.bountyTextSecondary)
            }
            Spacer()

            Text("\(item.beansText(for: currentUserID)) beans")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(item.perspective(for: currentUserID) == .transferOut ? .bountyTextSecondary : (item.isIncome(for: currentUserID) ? .bountySuccess : .bountyDanger))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct WalletData: Codable {
    let balance: Double
    let frozenBalance: Double
    let totalEarned: Double
    let totalSpent: Double
    let canWithdraw: Bool
    let beansPurchased: Int
    let beansEarned: Int
    let beansTotal: Int
    let completedTasks: Int?

    enum CodingKeys: String, CodingKey {
        case balance
        case canWithdraw = "can_withdraw"
        case frozenBalance = "frozen_balance"
        case totalEarned = "total_earned"
        case totalSpent = "total_spent"
        case beansPurchased = "beans_purchased"
        case beansEarned = "beans_earned"
        case beansTotal = "beans_total"
        case completedTasks = "completed_tasks"
    }
}
