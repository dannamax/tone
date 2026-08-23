import SwiftUI

struct WalletView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @StateObject private var vm = WalletViewModel()
    @State private var showPackages = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 发布额度主卡片
                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Text(L10n.quotaRemainingTitle)
                                .font(.system(size: 13))
                                .foregroundColor(.bountyTextSecondary)
                            Text("\(vm.publishQuota)")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.bountyText)
                            Text(String(format: L10n.quotaUsedFmt, vm.usedQuota))
                                .font(.system(size: 12))
                                .foregroundColor(.bountyGray)
                        }
                        .padding(.top, 12)

                        Button {
                            showPackages = true
                        } label: {
                            Text(L10n.quotaBuyButton)
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

                    // 余额卡片（保留，展示真实资金而非提现入口）
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.walletBalance)
                                .font(.system(size: 13))
                                .foregroundColor(.bountyTextSecondary)
                            Text(String(format: "¥%.2f", vm.balance))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.bountyText)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing:  4) {
                            Text(L10n.walletFrozen)
                                .font(.system(size: 13))
                                .foregroundColor(.bountyTextSecondary)
                            Text(String(format: "¥%.2f", vm.frozenBalance))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.bountyText)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)

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
        .onAppear { vm.load() }
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
                                    Text(pkg.localizedQuota)
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
    @Published var balance: Double = 0
    @Published var frozenBalance: Double = 0
    @Published var totalEarned: Double = 0
    @Published var canWithdraw = false
    @Published var publishQuota: Int = 0
    @Published var usedQuota: Int = 0
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
                        self.balance = data.balance
                        self.frozenBalance = data.frozenBalance
                        self.totalEarned = data.totalEarned
                        self.canWithdraw = data.canWithdraw
                        self.publishQuota = data.publishQuota
                        self.usedQuota = data.usedQuota
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
            _ = try await StoreKitManager.shared.purchase(productSKU: pkg.id, orderID: order.id)
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
    let publishQuota: Int
    let usedQuota: Int

    enum CodingKeys: String, CodingKey {
        case balance
        case canWithdraw = "can_withdraw"
        case frozenBalance = "frozen_balance"
        case totalEarned = "total_earned"
        case totalSpent = "total_spent"
        case publishQuota = "publish_quota"
        case usedQuota = "used_quota"
    }
}
