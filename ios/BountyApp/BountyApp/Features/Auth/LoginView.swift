import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LoginViewModel()
    #if !PRODUCTION
    @State private var showServerSettings = false
    #endif
    @State private var showPrivacyConsent = false
    @FocusState private var focusedField: Field?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private enum Field { case email, code }

    private var isCompact: Bool {
        verticalSizeClass == .compact || focusedField == .email
    }

    var body: some View {
        ZStack {
            // 背景已由 BountyApp.swift 根容器铺满；这里不再重复设置，
            // 避免 GeometryReader 限制安全区域传播。
            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            headerView
                                .opacity(isCompact ? 0 : 1)
                                .frame(height: isCompact ? 0 : nil)
                                .animation(.easeInOut(duration: 0.2), value: isCompact)

                            VStack(alignment: .leading, spacing: 28) {
                                emailSection

                                if viewModel.showCodeField {
                                    codeSection
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, isCompact ? 16 : 8)

                            Spacer(minLength: 24)

                            bottomActions
                                .padding(.horizontal, 24)
                                .padding(.bottom, 16)
                        }
                        .frame(minHeight: geo.size.height)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: focusedField) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
            }

            topBar
        }
        #if !PRODUCTION
        .sheet(isPresented: $showServerSettings) {
            ServerSettingsView()
        }
        #endif
        .sheet(isPresented: $showPrivacyConsent) {
            PrivacyConsentView()
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(title: Text(L10n.loginErrorTitle),
                  message: Text(viewModel.errorMessage),
                  dismissButton: .default(Text(L10n.ok)))
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundColor(.white)
                .padding(13)
                .background(
                    LinearGradient(
                        colors: [.bountyGold, Color(hex: "#FF8C42")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .bountyGold.opacity(0.22), radius: 14, x: 0, y: 5)

            Text(L10n.appName)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.bountyText)

            Text(L10n.appSlogan)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.bountyTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 36)
    }

    // MARK: - Email Section

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.loginEmailPlaceholder)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.bountyTextSecondary)
                .padding(.leading, 4)

            HStack(spacing: 8) {
                Image(systemName: "envelope")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.bountyGray)
                    .frame(width: 20)

                TextField("", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.bountyText)
                    .padding(.vertical, 14)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
            .padding(.horizontal, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focusedField == .email ? Color.bountyGold.opacity(0.5) : Color.bountyGray.opacity(0.12),
                            lineWidth: 1)
            )

            HStack {
                Spacer()
                Button(action: requestCode) {
                    Group {
                        if viewModel.isCountingDown {
                            Text(String(format: L10n.loginRetryAfter, viewModel.countdown))
                        } else {
                            Text(L10n.loginGetCode)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.canRequestCode ? .bountyGold : .bountyGray)
                }
                .disabled(!viewModel.canRequestCode)
            }
        }
    }

    // MARK: - Code Section

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.loginCodePlaceholder)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.bountyTextSecondary)
                .padding(.leading, 4)

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    CodeDigitBox(index: index, code: viewModel.verificationCode, isFocused: focusedField == .code)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // 点击数字框区域即聚焦隐藏 TextField，弹出键盘
                focusedField = .code
            }
            .overlay {
                TextField("", text: $viewModel.verificationCode)
                    .keyboardType(.numberPad)
                    .opacity(0.01)
                    .accessibilityIdentifier("verificationCodeField")
                    .accessibilityHidden(false)
                    .focused($focusedField, equals: .code)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .onChange(of: viewModel.verificationCode) { value in
                        if value.count >= 6 {
                            focusedField = nil
                            verifyCode()
                        }
                    }
            }
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 16) {
            Button(action: viewModel.showCodeField ? verifyCode : requestCode) {
                HStack {
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(viewModel.showCodeField ? L10n.loginVerify : L10n.loginGetCode)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(canProceed ? Color.bountyDark : Color.bountyGray.opacity(0.35))
                )
            }
            .accessibilityIdentifier("primaryActionButton")
            .disabled(!canProceed)
            .id("bottomAnchor")

            Button {
                showPrivacyConsent = true
            } label: {
                Text(L10n.loginAgreementHint)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.bountyTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .buttonStyle(.plain)
        }
    }

    private var topBar: some View {
        VStack {
            HStack {
                Spacer()
                #if !PRODUCTION
                Button {
                    showServerSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.bountyTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.top, 10)
                .padding(.trailing, 16)
                #endif
            }
            Spacer()
        }
    }

    // MARK: - Logic

    private var canProceed: Bool {
        if viewModel.showCodeField {
            return viewModel.verificationCode.count == 6 && !viewModel.isLoading
        }
        return viewModel.canRequestCode
    }

    private func requestCode() {
        viewModel.requestVerificationCode(email: viewModel.email) {
            // 发码成功后自动弹出键盘，聚焦到验证码输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedField = .code
            }
        }
    }

    private func verifyCode() {
        viewModel.verifyCode(email: viewModel.email) { user, token in
            appState.login(user: user, token: token)
        }
    }
}

// MARK: - Code Digit Box

struct CodeDigitBox: View {
    let index: Int
    let code: String
    let isFocused: Bool

    private var digit: String {
        let chars = Array(code)
        return index < chars.count ? String(chars[index]) : ""
    }

    var body: some View {
        Text(digit)
            .font(.system(size: 20, weight: .semibold, design: .monospaced))
            .foregroundColor(.bountyText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: isFocused && digit.isEmpty ? 1.5 : 1)
            )
    }

    private var strokeColor: Color {
        if !digit.isEmpty {
            return .bountyGold
        }
        return isFocused ? Color.bountyGold.opacity(0.5) : Color.bountyGray.opacity(0.15)
    }
}

// MARK: - View Model

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var verificationCode = ""
    @Published var showCodeField = false
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var countdown = 0

    private var timer: Timer?

    var canRequestCode: Bool {
        isValidEmail(email) && !isLoading && !isCountingDown
    }

    var isCountingDown: Bool {
        countdown > 0
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$") else {
            return false
        }
        return regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.count)) != nil
    }

    func requestVerificationCode(email: String, onSuccess: (() -> Void)? = nil) {
        isLoading = true
        Task {
            do {
                let body: [String: Any] = ["email": email.lowercased()]
                let _: APIResponse<EmptyResponse> = try await APIClient.shared.request("/auth/send-code", method: "POST", body: body, requiresAuth: false)
                await MainActor.run {
                    isLoading = false
                    showCodeField = true
                    startCountdown()
                    onSuccess?()
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.friendlyMessage
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = L10n.apiNetworkError
                    showError = true
                }
            }
        }
    }

    func verifyCode(email: String, completion: @escaping (UserProfile, String) -> Void) {
        isLoading = true
        Task {
            do {
                let deviceID = TokenStorage.shared.deviceID ?? UUID().uuidString
                if TokenStorage.shared.deviceID == nil {
                    TokenStorage.shared.deviceID = deviceID
                }
                let body: [String: Any] = [
                    "email": email.lowercased(),
                    "code": verificationCode,
                    "device_id": deviceID
                ]
                let response: APIResponse<TokenResponse> = try await APIClient.shared.request("/auth/login", method: "POST", body: body, requiresAuth: false)
                await MainActor.run {
                    isLoading = false
                    if let tokenResp = response.data {
                        let user = UserProfile(
                            id: tokenResp.user.id,
                            email: tokenResp.user.email,
                            nickname: tokenResp.user.nickname,
                            avatar: tokenResp.user.avatar,
                            balance: tokenResp.user.balance,
                            frozenBalance: tokenResp.user.frozenBalance
                        )
                        completion(user, tokenResp.accessToken)
                    } else {
                        errorMessage = L10n.loginAuthFailed
                        showError = true
                    }
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.friendlyMessage
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = L10n.apiNetworkError
                    showError = true
                }
            }
        }
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.countdown > 0 {
                self.countdown -= 1
            } else {
                self.timer?.invalidate()
                self.timer = nil
            }
        }
    }
}

struct EmptyResponse: Codable {}

struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int64
    let user: TokenUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case user
    }
}

struct TokenUser: Codable {
    let id: String
    let email: String
    let nickname: String
    let avatar: String
    let balance: Double
    let frozenBalance: Double

    enum CodingKeys: String, CodingKey {
        case id, email, nickname, avatar, balance
        case frozenBalance = "frozen_balance"
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AppState())
    }
}
