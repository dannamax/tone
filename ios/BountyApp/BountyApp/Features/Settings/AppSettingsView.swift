import SwiftUI

// MARK: - App Settings View
/// Full settings page for the app — accessible from Profile → Settings.
/// Covers language, country/region, permissions, privacy, and about.

struct AppSettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var lang = LanguageManager.shared
    @State private var showLanguagePicker = false
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
                    openPrivacyPolicy()
                } label: {
                    settingsRow(
                        icon: "hand.raised.fill", iconColor: .bountyInfo,
                        title: L10n.settingsPrivacyPolicy,
                        value: nil
                    )
                }

                Button {
                    openTermsOfService()
                } label: {
                    settingsRow(
                        icon: "doc.text.fill", iconColor: .bountyGray,
                        title: L10n.settingsTermsOfService,
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

                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundColor(.bountyTextSecondary)
                        .font(.system(size: 15))
                }

                HStack {
                    Label {
                        Text(L10n.settingsBuild)
                            .foregroundColor(.bountyText)
                    } icon: {
                        Image(systemName: "number")
                            .foregroundColor(.bountyGray)
                    }

                    Spacer()

                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundColor(.bountyTextSecondary)
                        .font(.system(size: 15))
                }
            } header: {
                Text(L10n.settingsAbout)
            }

            // MARK: Logout
            Section {
                Button(role: .destructive) {
                    appState.logout()
                } label: {
                    HStack {
                        Spacer()
                        Text(L10n.profileLogoutAction)
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                    }
                }
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

    // MARK: - External Links

    private func openPrivacyPolicy() {
        if let url = URL(string: AppConfig.privacyPolicyURL) {
            UIApplication.shared.open(url)
        }
    }

    private func openTermsOfService() {
        if let url = URL(string: AppConfig.termsOfServiceURL) {
            UIApplication.shared.open(url)
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
