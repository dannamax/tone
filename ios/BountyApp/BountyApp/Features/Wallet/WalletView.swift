import SwiftUI

struct WalletView: View {
    @StateObject private var vm = WalletViewModel()
    @State private var showWithdraw = false
    @State private var showRecharge = false
    @State private var withdrawAmount: Double = 0
    @State private var withdrawChannel = "bank"
    @State private var rechargeAmount: Double = 100

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Text(L10n.walletBalance)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                        Text("¥\(String(format: "%.2f", vm.balance))")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        HStack(spacing: 20) {
                            VStack {
                                Text("¥\(String(format: "%.2f", vm.frozenBalance))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                Text(L10n.walletFrozen)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            VStack {
                                Text("¥\(String(format: "%.2f", vm.totalEarned))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                Text(L10n.walletTotalEarned)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.bountyDark, Color(hex: "#2D2D4E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)

                    if let error = vm.loadError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    }

                    Button(action: { showWithdraw = true }) {
                        HStack {
                            Image(systemName: "arrow.down.to.line")
                            Text(L10n.walletWithdraw)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(vm.canWithdraw ? Color.bountyGold : Color.bountyGray)
                        .cornerRadius(12)
                    }
                    .disabled(!vm.canWithdraw)
                    .opacity(vm.canWithdraw ? 1.0 : 0.6)

                    Button(action: { showRecharge = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text(L10n.walletRechargeSim)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.bountyText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.bountyBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.bountyGold, lineWidth: 1)
                        )
                    }

                    if !vm.canWithdraw && vm.balance > 0 {
                        Text(L10n.walletMinWithdraw)
                            .font(.system(size: 12))
                            .foregroundColor(.bountyGray)
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

                        Divider().padding(.leading, 52)

                        NavigationLink {
                            Text(L10n.walletHelpPage)
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.bountyText)
                                Text(L10n.walletHelp)
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
        .sheet(isPresented: $showWithdraw) {
            VStack(spacing: 24) {
                Text(L10n.walletWithdrawTitle)
                    .font(.system(size: 18, weight: .bold))

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.walletWithdrawAmount)
                        .font(.system(size: 14, weight: .medium))
                    HStack {
                        Text("¥").font(.system(size: 22, weight: .bold))
                        TextField(L10n.walletMinWithdraw, value: $withdrawAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 22, weight: .bold))
                    }
                    .padding()
                    .background(Color.bountyBg)
                    .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.walletWithdrawMethod)
                        .font(.system(size: 14, weight: .medium))
                    HStack(spacing: 10) {
                        ForEach(["bank", "paypal"], id: \.self) { ch in
                            Button(ch == "bank" ? L10n.walletWithdrawBank : L10n.walletWithdrawPaypal) {
                                withdrawChannel = ch
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(withdrawChannel == ch ? .white : .bountyTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(withdrawChannel == ch ? Color.bountyGold : Color.white)
                            )
                        }
                    }
                }

                Text(L10n.walletWithdrawETA)
                    .font(.system(size: 12))
                    .foregroundColor(.bountyGray)

                Button(L10n.walletWithdrawConfirm) {
                    vm.withdraw(amount: withdrawAmount, channel: withdrawChannel)
                    showWithdraw = false
                }
                .bountyButton()
                .disabled(withdrawAmount < 10)
                .opacity(withdrawAmount >= 10 ? 1.0 : 0.5)
            }
            .padding(24)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRecharge) {
            VStack(spacing: 24) {
                Text(L10n.walletRechargeSim)
                    .font(.system(size: 18, weight: .bold))

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.walletRechargeAmount)
                        .font(.system(size: 14, weight: .medium))
                    HStack {
                        Text("¥").font(.system(size: 22, weight: .bold))
                        TextField(L10n.walletRechargePlaceholder, value: $rechargeAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 22, weight: .bold))
                    }
                    .padding()
                    .background(Color.bountyBg)
                    .cornerRadius(12)
                }

                Text(L10n.walletRechargeHint)
                    .font(.system(size: 12))
                    .foregroundColor(.bountyGray)

                Button(L10n.walletRechargeConfirm) {
                    vm.recharge(amount: rechargeAmount)
                    showRecharge = false
                }
                .bountyButton()
                .disabled(rechargeAmount <= 0)
                .opacity(rechargeAmount > 0 ? 1.0 : 0.5)
            }
            .padding(24)
            .presentationDetents([.medium, .large])
        }
        .onAppear { vm.load() }
    }
}

class WalletViewModel: ObservableObject {
    @Published var balance: Double = 0
    @Published var frozenBalance: Double = 0
    @Published var totalEarned: Double = 0
    @Published var canWithdraw = false
    @Published var loadError: String?
    @Published var isLoading = false

    func load() {
        Task {
            await MainActor.run { isLoading = true }
            do {
                let resp: APIResponse<WalletData> = try await APIClient.shared.request("/wallet")
                await MainActor.run {
                    isLoading = false
                    if resp.code == 0, let data = resp.data {
                        self.balance = data.balance
                        self.frozenBalance = data.frozenBalance
                        self.totalEarned = data.totalEarned
                        self.canWithdraw = data.canWithdraw
                        self.loadError = nil
                    } else {
                        self.loadError = resp.message.isEmpty ? L10n.walletLoadFailed : resp.message
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let err = error as? APIError, case .unauthorized = err {
                        self.loadError = L10n.walletAuthExpired
                    } else {
                        self.loadError = L10n.networkError
                    }
                }
            }
        }
    }

    func withdraw(amount: Double, channel: String) {
        Task {
            do {
                let resp: APIResponse<EmptyResponse> = try await APIClient.shared.request(
                    "/wallet/withdraw",
                    method: "POST",
                    body: ["amount": amount, "channel": channel, "account": "user_account"]
                )
                guard resp.code == 0 else {
                    await MainActor.run { self.loadError = resp.message.isEmpty ? L10n.walletWithdrawFailed : resp.message }
                    return
                }
                await load()
            } catch {
                await MainActor.run {
                    self.loadError = L10n.walletWithdrawFailed
                }
            }
        }
    }

    func recharge(amount: Double) {
        Task {
            do {
                print("[WalletVM] recharge amount=\(amount), token=\(TokenStorage.shared.token ?? "nil")")
                let resp: APIResponse<WalletData> = try await APIClient.shared.request(
                    "/wallet/recharge",
                    method: "POST",
                    body: ["amount": amount]
                )
                print("[WalletVM] recharge resp code=\(resp.code), msg=\(resp.message)")
                guard resp.code == 0 else {
                    await MainActor.run { self.loadError = resp.message.isEmpty ? L10n.walletRechargeFailed : resp.message }
                    return
                }
                await MainActor.run {
                    if let data = resp.data {
                        self.balance = data.balance
                        self.frozenBalance = data.frozenBalance
                        self.totalEarned = data.totalEarned
                        self.canWithdraw = data.canWithdraw
                    } else {
                        self.balance += amount
                    }
                    self.loadError = nil
                }
            } catch {
                print("[WalletVM] recharge error: \(error)")
                await MainActor.run {
                    self.loadError = L10n.walletRechargeFailed + ": \(error.localizedDescription)"
                }
            }
        }
    }
}

struct TransactionListView: View {
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

    enum CodingKeys: String, CodingKey {
        case balance
        case canWithdraw = "can_withdraw"
        case frozenBalance = "frozen_balance"
        case totalEarned = "total_earned"
        case totalSpent = "total_spent"
    }
}
