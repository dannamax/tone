import SwiftUI
import WebKit

/// GDPR / privacy consent view shown on first app launch.
struct PrivacyConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared
    @AppStorage("hasAcceptedPrivacyPolicy") private var hasAccepted = false
    @State private var showPolicy = false
    @State private var showTerms = false
    @State private var showDeclineAlert = false

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
                    // User declined — must accept to continue; stay on consent screen.
                    showDeclineAlert = true
                } label: {
                    Text(L10n.privacyConsentDisagree)
                        .font(.system(size: 14))
                        .foregroundColor(.bountyGray)
                        .padding(.vertical, 10)
                }
            }
            .alert(L10n.privacyConsentTitle, isPresented: $showDeclineAlert) {
                Button(L10n.ok, role: .cancel) { }
            } message: {
                Text(L10n.privacyConsentRequired)
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

/// In-app WebView showing policy / terms pages.
struct WebViewPlaceholder: View {
    let title: String
    let url: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        NavigationView {
            ZStack {
                if let loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.bountyGray)
                        Text(loadError)
                            .font(.system(size: 14))
                            .foregroundColor(.bountyTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                } else {
                    WebView(urlString: url, isLoading: $isLoading, loadError: $loadError)
                    if isLoading {
                        ProgressView()
                    }
                }
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

/// UIViewRepresentable wrapper around WKWebView.
struct WebView: UIViewRepresentable {
    let urlString: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        } else {
            loadError = String(format: L10n.webviewInvalidUrl, urlString)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        init(_ parent: WebView) { self.parent = parent }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }
    }
}
