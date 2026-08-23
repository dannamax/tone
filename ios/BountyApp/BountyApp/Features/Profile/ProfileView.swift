import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var lang = LanguageManager.shared
    @State private var showLogoutConfirm = false

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
                                    Text("¥\(String(format: "%.2f", user.balance))")
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

                        ProfileRow(icon: "questionmark.circle", title: L10n.profileHelp, color: .bountyInfo) {}

                        Divider().padding(.leading, 52)

                        ProfileRow(icon: "doc.text", title: L10n.profileTerms, color: .bountyGray) {}

                        Divider().padding(.leading, 52)

                        ProfileRow(icon: "shield.checkered", title: L10n.profilePrivacy, color: .bountyGray) {}
                    }
                    .cornerRadius(12)

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
