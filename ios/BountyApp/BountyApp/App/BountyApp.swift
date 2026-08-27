import SwiftUI

@main
struct SeekerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var lang = LanguageManager.shared

    init() {
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

/// APNs 远程推送生命周期（PushManager 详见 Core/Push/PushManager.swift）
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 请求通知权限并注册远程通知（模拟器/未开 capability 时静默失败）
        PushManager.shared.bootstrap()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushManager.shared.didFailToRegister(error: error)
    }
}
