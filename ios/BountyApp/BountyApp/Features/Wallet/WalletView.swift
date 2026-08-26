import SwiftUI

struct WalletView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @StateObject private var vm = WalletViewModel()
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
        .onAppear { vm.load() }
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
}

struct TransactionListView: View {
    @ObservedObject private var lang = LanguageManager.shared
    var body: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.walletBounty).font(.system(size: 14, weight: .medium))
                        Text(Date().timeAgoDisplay()).font(.system(size: 12)).foregroundColor(.bountyTextSecondary)
                    }
                    Spacer()
                    Text("+¥18.00").font(.system(size: 16, weight: .medium)).foregroundColor(.bountySuccess)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(L10n.walletTransactions)
        .background(Color.bountyBg)
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
