import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var language: LanguageManager
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.bountyBg.ignoresSafeArea()

            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 0) {
                    headerView
                        .padding(.horizontal, 24)
                        .padding(.top, geo.safeAreaInsets.top > 20 ? 32 : 24)

                    contentView
                        .padding(.top, 32)

                    Spacer(minLength: 16)

                    continueButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.onboardingLangTitle)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.bountyText)

            Text(L10n.onboardingLangSubtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.bountyTextSecondary)
                .lineSpacing(2)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 12)
        .animation(.easeOut(duration: 0.4).delay(0.1), value: isAnimating)
    }

    // MARK: - Content

    private var contentView: some View {
        languageList
    }

    private var languageList: some View {
        VStack(spacing: 10) {
            ForEach(Array(AppLanguage.supported.enumerated()), id: \.element.code) { index, lang in
                OptionRow(
                    title: lang.nativeName,
                    subtitle: lang.englishName,
                    icon: lang.flag,
                    isSelected: language.currentCode == lang.code,
                    delay: Double(index) * 0.05
                ) {
                    // 选择即生效，onboarding 文案会立即切换
                    language.switchTo(lang.code)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: handleContinue) {
            HStack {
                Spacer()
                Text(L10n.onboardingGetStarted)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.bountyDark)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleContinue() {
        appState.completeOnboarding()
    }
}

// MARK: - Option Row

struct OptionRow: View {
    let title: String
    let subtitle: String
    var icon: String? = nil
    let isSelected: Bool
    let delay: Double
    let action: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Text(icon)
                        .font(.system(size: 20))
                        .frame(width: 28, alignment: .leading)
                }

                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.bountyText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 12)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.bountyTextSecondary)
                    .frame(minWidth: 44, alignment: .trailing)

                selectionIndicator
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.bountyGold.opacity(0.08) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.bountyGold.opacity(0.35) : Color.bountyGray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.bountyGold)
                .transition(.scale.combined(with: .opacity))
        } else {
            Circle()
                .stroke(Color.bountyGray.opacity(0.25), lineWidth: 1.5)
                .frame(width: 20, height: 20)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(AppState())
    }
}
