import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var lang = LanguageManager.shared
    @State private var showLogoutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false

    /// 删除账户：调 DELETE /me 彻底清除服务端数据，成功后清空本地登录态。
    /// 有进行中任务时后端返回 409，toast 提示先完成或放弃。
    private func deleteAccount() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        Task { @MainActor in
            do {
                let resp: APIResponse<EmptyResponse> = try await APIClient.shared.request(
                    "/me", method: "DELETE"
                )
                isDeletingAccount = false
                if resp.code == 0 {
                    appState.logout()
                } else {
                    appState.showToast(resp.message.isEmpty ? L10n.profileDeleteAccountFailed : resp.message)
                }
            } catch {
                isDeletingAccount = false
                appState.showToast((error as? APIError)?.friendlyMessage ?? L10n.profileDeleteAccountFailed)
            }
        }
    }

    private func openHelpAndFeedback() {
        let supportEmail = "support@gotseeker.com"
        let subject = "[SeekerHub] App Feedback"
        let body = "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
        let mailto = "mailto:\(supportEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        if let url = URL(string: mailto), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Avatar & User Info
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.bountyGold.opacity(0.3), .bountyGold.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)

                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.bountyGold)
                        }

                        if let user = appState.currentUser {
                            Text(user.nickname)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.bountyText)
                            Text("ID: \(String(user.id.prefix(8)))...")
                                .font(.system(size: 12))
                                .foregroundColor(.bountyTextSecondary)
                        }
                    }
                    .padding(.vertical, 24)

                    // Wallet & Tasks
                    VStack(spacing: 0) {
                        NavigationLink {
                            WalletView()
                        } label: {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                    .foregroundColor(.bountyGold)
                                Text(L10n.profileWallet)
                                    .foregroundColor(.bountyText)
                                Spacer()
                                if let user = appState.currentUser {
                                    Text(String(format: L10n.beansPackageCountFmt, user.beansTotal))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.bountyGold)
                                }
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
                            MyTasksView()
                        } label: {
                            HStack {
                                Image(systemName: "list.clipboard")
                                    .foregroundColor(.bountyInfo)
                                Text(L10n.profileMyTasks)
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

                    // Settings & Support
                    VStack(spacing: 0) {
                        NavigationLink {
                            AppSettingsView()
                                .environmentObject(appState)
                        } label: {
                            HStack {
                                Image(systemName: "gearshape")
                                    .foregroundColor(.bountyGray)
                                Text(L10n.profileSettings)
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

                        ProfileRow(icon: "questionmark.circle", title: L10n.profileHelp, color: .bountyInfo) {
                            openHelpAndFeedback()
                        }
                    }
                    .cornerRadius(12)

                    // Terms & privacy live in Settings to avoid duplicated entries.

                    // Logout
                    Button(action: { showLogoutConfirm = true }) {
                        Text(L10n.profileLogout)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.bountyDanger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                    }

                    // Delete Account（App Store 5.1.1(v) / GDPR 合规）
                    Button(action: { showDeleteAccountConfirm = true }) {
                        Text(L10n.profileDeleteAccount)
                            .font(.system(size: 13))
                            .foregroundColor(.bountyGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color.bountyBg)
            .navigationTitle(L10n.profileTitle)
        }
        .confirmationDialog(L10n.profileLogoutConfirm, isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button(L10n.profileLogoutAction, role: .destructive) {
                appState.logout()
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        // 删除账户二次确认：不可恢复，需无进行中任务
        .confirmationDialog(L10n.profileDeleteAccountConfirmTitle, isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
            Button(L10n.profileDeleteAccountAction, role: .destructive) {
                deleteAccount()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.profileDeleteAccountConfirmMsg)
        }
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    let color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
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
}
