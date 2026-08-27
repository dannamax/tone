import Foundation
import UserNotifications
import UIKit

/// APNs 远程推送管理：
/// 1. 启动后请求通知权限（授权后才向 APNs 注册拿 device token）
/// 2. token 上报后端 POST /devices/register（同一 token 换账号登录会重新归属）
/// 3. 前台收到通知时横幅展示；点击通知由系统路由到 App
///
/// 注意：需要 Xcode target 开启 Push Notifications capability
/// （aps-environment entitlement），否则真机上注册拿不到 token。
final class PushManager: NSObject, ObservableObject {
    static let shared = PushManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// 已获取但尚未成功上报后端的 APNs token（登录前/上报失败时缓存）
    private var pendingToken: String?

    /// App 启动时调用：请求权限 → 注册远程通知
    func bootstrap() {
        let center = UNUserNotificationCenter.current()
        center.delegate = PushDelegate.shared
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        self?.authorizationStatus = granted ? .authorized : .denied
                    }
                    if granted {
                        self?.registerForRemoteNotifications()
                    }
                }
            case .authorized, .provisional, .ephemeral:
                self?.registerForRemoteNotifications()
            default:
                break // .denied：不再骚扰，用户可去系统设置开启
            }
        }
    }

    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// 系统回调：APNs token 到手 → 缓存并尝试上报（未登录时仅缓存，登录后再上报）
    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[Push] APNs device token: \(token.prefix(16))...")
        guard !APIClient.isUITestMode else { return }
        pendingToken = token
        UserDefaults.standard.set(token, forKey: "push_device_token")
        reportPendingToken()
    }

    /// 登录成功 / 会话恢复后调用：把缓存的上报给后端
    func reportPendingToken() {
        guard let token = pendingToken ?? UserDefaults.standard.string(forKey: "push_device_token"),
              !token.isEmpty else { return }
        pendingToken = token
        Task { [weak self] in
            guard let resp: APIResponse<EmptyResponse> = try? await APIClient.shared.request(
                "/devices/register",
                method: "POST",
                body: ["token": token, "platform": "ios"],
                requiresAuth: true
            ), resp.code == 0 else { return }
            await MainActor.run { self?.pendingToken = nil }
        }
    }

    func didFailToRegister(error: Error) {
        // 最常见原因：模拟器（不支持 APNs 注册）或缺少 Push capability
        print("[Push] register failed: \(error.localizedDescription)")
    }
}

/// UNUserNotificationCenterDelegate：前台也展示横幅
final class PushDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // App 在前台：横幅 + 声音 + 角标
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 点击通知：payload 里带 task_id 时可深链到任务详情（后续迭代）
        completionHandler()
    }
}
