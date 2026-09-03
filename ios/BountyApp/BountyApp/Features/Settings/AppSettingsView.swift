import SwiftUI

// MARK: - App Settings View
/// Full settings page for the app — accessible from Profile → Settings.
/// Covers language, country/region, permissions, privacy, and about.

struct AppSettingsView: View {
    @StateObject private var lang = LanguageManager.shared
    @State private var showLanguagePicker = false
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false
    @State private var notifyEnabled = UserDefaults.standard.bool(forKey: "settings_notify")

    var body: some View {
        List {
            // MARK: General
            Section {
                Button { showLanguagePicker = true } label: {
                    settingsRow(
                        icon: "globe", iconColor: .bountyGold,
                        title: L10n.settingsLanguage,
                        value: lang.currentLanguage.nativeName
                    )
                }
            } header: {
                Text(L10n.settingsSectionGeneral)
            }

            // MARK: Notifications
            Section {
                Toggle(isOn: $notifyEnabled) {
                    Label {
                        Text(L10n.settingsNotifications)
                            .foregroundColor(.bountyText)
                    } icon: {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.bountyDanger)
                    }
                }
                .tint(.bountyGold)
                .onChange(of: notifyEnabled) { newVal in
                    UserDefaults.standard.set(newVal, forKey: "settings_notify")
                }
            } header: {
                Text(L10n.settingsSectionNotifications)
            }

            // MARK: Privacy & Legal
            Section {
                Button {
                    showPrivacySheet = true
                } label: {
                    settingsRow(
                        icon: "hand.raised.fill", iconColor: .bountyInfo,
                        title: L10n.settingsPrivacyPolicy,
                        value: nil
                    )
                }

                Button {
                    showTermsSheet = true
                } label: {
                    settingsRow(
                        icon: "doc.text.fill", iconColor: .bountyGray,
                        title: L10n.settingsTermsOfService,
                        value: nil
                    )
                }

                NavigationLink {
                    BlockedUsersView()
                } label: {
                    settingsRow(
                        icon: "person.slash.fill", iconColor: .bountyDanger,
                        title: L10n.blockedUsers,
                        value: nil
                    )
                }
            } header: {
                Text(L10n.settingsSectionPrivacy)
            }

            // MARK: About
            Section {
                HStack {
                    Label {
                        Text(L10n.settingsVersion)
                            .foregroundColor(.bountyText)
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.bountyGray)
                    }

                    Spacer()

                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    Text("\(version) (\(build))")
                        .foregroundColor(.bountyTextSecondary)
                        .font(.system(size: 15))
                }
            } header: {
                Text(L10n.settingsAbout)
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.bountyBg)
        .scrollContentBackground(.hidden)
        .navigationTitle(L10n.settingsTitle)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
        }
        .sheet(isPresented: $showPrivacySheet) {
            WebViewPlaceholder(title: L10n.profilePrivacy, url: AppConfig.privacyPolicyURL)
        }
        .sheet(isPresented: $showTermsSheet) {
            WebViewPlaceholder(title: L10n.profileTerms, url: AppConfig.termsOfServiceURL)
        }
    }

    // MARK: - Row Builder

    private func settingsRow(icon: String, iconColor: Color, title: String, value: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.bountyText)

            Spacer()

            if let value = value {
                Text(value)
                    .foregroundColor(.bountyTextSecondary)
                    .font(.system(size: 15))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.bountyGray.opacity(0.5))
        }
        .font(.system(size: 16))
    }

    // MARK: - Language Picker Sheet

    private var languagePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.supported) { language in
                    Button {
                        LanguageManager.shared.switchTo(language.code)
                        showLanguagePicker = false
                    } label: {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.system(size: 28))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.nativeName)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.bountyText)
                                Text(language.englishName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.bountyTextSecondary)
                            }

                            Spacer()

                            if lang.currentCode == language.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.bountyGold)
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle(L10n.settingsLanguage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.done) { showLanguagePicker = false }
                }
            }
        }
    }
}

// MARK: - Preview

struct AppSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AppSettingsView()
                .environmentObject(AppState())
        }
    }
}

// MARK: - Blocked Users View (Guideline 1.2 UGC)

struct BlockedUser: Codable, Identifiable {
    let userID: String
    let nickname: String
    let createdAt: String

    var id: String { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nickname
        case createdAt = "created_at"
    }
}

struct BlockedUsersView: View {
    @EnvironmentObject var appState: AppState
    @State private var users: [BlockedUser] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                EmptyStateView(
                    icon: "person.slash",
                    title: L10n.blockedUsers,
                    subtitle: L10n.blockedUsersEmpty
                )
            } else {
                List {
                    ForEach(users) { user in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.nickname.isEmpty ? user.userID : user.nickname)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.bountyText)
                                Text(user.userID)
                                    .font(.system(size: 11))
                                    .foregroundColor(.bountyTextSecondary)
                            }
                            Spacer()
                            Button(L10n.unblock) {
                                unblock(user)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.bountyInfo)
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color.bountyBg)
        .scrollContentBackground(.hidden)
        .navigationTitle(L10n.blockedUsers)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }

    private func load() {
        isLoading = users.isEmpty
        Task { @MainActor in
            do {
                let resp: APIResponse<[BlockedUser]> = try await APIClient.shared.request("/users/blocked")
                users = resp.data ?? []
            } catch {
                print("[BlockedUsers] load error: \(error)")
            }
            isLoading = false
        }
    }

    private func unblock(_ user: BlockedUser) {
        Task { @MainActor in
            do {
                _ = try await APIClient.shared.request(
                    "/users/\(user.userID)/block", method: "DELETE"
                ) as APIResponse<String>
                withAnimation { users.removeAll { $0.userID == user.userID } }
                appState.showToast(L10n.userUnblocked)
            } catch {
                print("[BlockedUsers] unblock error: \(error)")
            }
        }
    }
}
