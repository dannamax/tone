import SwiftUI

@main
struct SeekerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var lang = LanguageManager.shared

    init() {
        // UI 测试模式下重置首次启动与登录态，保证 onboarding 每次都出现。
        if ProcessInfo.processInfo.arguments.contains("-resetOnLaunch") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "auth_token")
            UserDefaults.standard.removeObject(forKey: "user_json")
            // 清理持久化的语言选择，避免连续运行时语言状态残留导致 onboarding 文案不一致
            UserDefaults.standard.removeObject(forKey: "app_language")
        }

        // 强制全局窗口背景与应用主题色一致，避免刘海/Home Indicator 区域
        // 在深色模式下露出系统默认黑色背景。
        UIWindow.appearance().backgroundColor = UIColor(Color.bountyBg)
    }

    var body: some Scene {
        WindowGroup {
            // 用一个铺满全屏的 ZStack 作为根容器，背景色延伸到刘海/Home Indicator 区域，
            // 所有子页面都在其上方布局，内容仍受安全区域保护。
            ZStack {
                Color.bountyBg

                Group {
                    if !appState.hasCompletedOnboarding {
                        OnboardingView()
                            .environmentObject(appState)
                    } else if appState.isLoggedIn {
                        RootView()
                            .environmentObject(appState)
                    } else {
                        LoginView()
                            .environmentObject(appState)
                    }
                }
                .environmentObject(lang)
            }
            // 切换语言时用 currentCode 作为 id，强制整个视图树销毁重建，
            // 确保所有已渲染的页面同步到新语言（L10n 已改为 static var 可重算）。
            .id(lang.currentCode)
            .ignoresSafeArea()
        }
    }
}
