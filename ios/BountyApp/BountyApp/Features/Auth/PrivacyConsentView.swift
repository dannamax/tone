import SwiftUI

/// GDPR / privacy consent view shown on first app launch.
struct PrivacyConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasAcceptedPrivacyPolicy") private var hasAccepted = false
    @State private var showPolicy = false
    @State private var showTerms = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundColor(.bountyGold)

            Text(L10n.privacyConsentTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.bountyDark)

            Text(L10n.privacyConsentBody)
                .font(.system(size: 15))
                .foregroundColor(.bountyTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)

            HStack(spacing: 16) {
                Button {
                    showPolicy = true
                } label: {
                    Text(L10n.profilePrivacy)
                        .font(.system(size: 13))
                        .foregroundColor(.bountyGold)
                        .underline()
                }
                .buttonStyle(.plain)

                Button {
                    showTerms = true
                } label: {
                    Text(L10n.profileTerms)
                        .font(.system(size: 13))
                        .foregroundColor(.bountyGold)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    hasAccepted = true
                    dismiss()
                } label: {
                    Text(L10n.privacyConsentAgree)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.bountyGold)
                        .cornerRadius(14)
                }
                .accessibilityIdentifier("privacyAgreeButton")

                Button {
                    // User declined — show confirmation then exit or dismiss
                    exit(0)
                } label: {
                    Text(L10n.privacyConsentDisagree)
                        .font(.system(size: 14))
                        .foregroundColor(.bountyGray)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.bountyBg.ignoresSafeArea())
        .sheet(isPresented: $showPolicy) {
            WebViewPlaceholder(title: L10n.profilePrivacy, url: AppConfig.privacyPolicyURL)
        }
        .sheet(isPresented: $showTerms) {
            WebViewPlaceholder(title: L10n.profileTerms, url: AppConfig.termsOfServiceURL)
        }
        .interactiveDismissDisabled()
    }
}

/// Placeholder for in-app WebView showing policy / terms pages.
struct WebViewPlaceholder: View {
    let title: String
    let url: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.bountyGray)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                Text(url)
                    .font(.system(size: 13))
                    .foregroundColor(.bountyTextSecondary)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
    }
}
