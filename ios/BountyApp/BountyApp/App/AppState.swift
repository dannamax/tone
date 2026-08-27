import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: UserProfile?
    @Published var unreadCount = 0
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var showPublishSheet = false
    @Published var refreshMyTasksTrigger = false
    @Published var refreshSquareTrigger = false

    /// Whether to show the GDPR privacy consent modal on first launch.
    @Published var showPrivacyConsent: Bool = !UserDefaults.standard.bool(forKey: "hasAcceptedPrivacyPolicy")

    /// Whether the user has completed the first-launch onboarding (language selection).
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    /// 用户当前经纬度（用于任务广场"附近"距离计算）
    @Published var userLat: Double = LocationManager.shared.userLat
    @Published var userLng: Double = LocationManager.shared.userLng
    private var locationCancellables = Set<AnyCancellable>()

    init() {
        // UI 测试模式：在自身初始化阶段就重置首次启动状态。
        // 必须早于 @Published 字段的默认值赋值（字段默认值与 init() 内的赋值时机：
        // Swift 按声明顺序执行属性初始化器，本 init() 在所有 @Published 之后被调用，
        // 但 @Published 的 default value 在 struct/class 字段声明处求值时已完成）。
        // 因此这里主动重新读取：先清 UserDefaults，再覆盖 @Published 值。
        if ProcessInfo.processInfo.arguments.contains("-resetOnLaunch") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "auth_token")
            UserDefaults.standard.removeObject(forKey: "user_json")
            UserDefaults.standard.removeObject(forKey: "app_language")
            UserDefaults.standard.removeObject(forKey: "hasAcceptedPrivacyPolicy")
            // 覆盖当前字段（默认值在 init 之前已锁定）
            self.hasCompletedOnboarding = false
            self.isLoggedIn = false
            self.currentUser = nil
            self.showPrivacyConsent = true
            self.unreadCount = 0
        }

        // 订阅全局定位更新，保持 AppState 中坐标同步
        LocationManager.shared.$userLat
            .receive(on: RunLoop.main)
            .sink { [weak self] lat in self?.userLat = lat }
            .store(in: &locationCancellables)
        LocationManager.shared.$userLng
            .receive(on: RunLoop.main)
            .sink { [weak self] lng in self?.userLng = lng }
            .store(in: &locationCancellables)

        // 延迟一帧启动定位，避免阻塞首屏渲染（登录页无需立即定位）
        DispatchQueue.main.async {
            LocationManager.shared.start()
        }

        // 启动网络监听：切换网络时取消挂起请求并提示（方案A）
        NetworkMonitor.shared
        NotificationCenter.default.addObserver(
            forName: .networkDidSwitch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showToast(L10n.networkSwitched)
            // 网络切换后触发后端地址重新发现
            AppConfig.clearCachedHost()
            AppConfig.rediscoverOnNetworkChange()
        }
        NotificationCenter.default.addObserver(
            forName: .networkDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showToast(L10n.networkDisconnected)
        }

        // 启动后台自动发现（首次请求会 await 等它完成，但仍不阻塞 UI）
        // 生产构建使用固定公网域名，无需局域网发现。
        #if !PRODUCTION
        AppConfig.launchDiscovery()
        #endif

        // 冷启动登录态恢复：App 被系统回收后重新打开时，读取上次登录
        // 保存的 token 与用户资料，避免每次冷启动都要求重新验证码登录。
        // （此前 token 虽已持久化但从未被读回，登录态仅存活于进程内存中，
        //  进程被杀即丢；服务端 JWT 有效期为 7 天。）
        restoreSessionIfNeeded()
    }

    /// 冷启动恢复登录态：先用本地缓存的用户资料乐观恢复 UI，
    /// 再后台调 GET /me 校验 token 是否仍有效：
    ///   - 有效 → 刷新最新资料（金豆余额等）
    ///   - 401/失效 → logout() 回到登录页（token 已过期，需重新验证码）
    ///   - 网络异常 → 保留本地登录态不打断用户，由后续请求失败时处理
    private func restoreSessionIfNeeded() {
        guard let token = TokenStorage.shared.token, !token.isEmpty,
              let json = TokenStorage.shared.userJSON,
              let data = json.data(using: .utf8),
              let user = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        currentUser = user
        isLoggedIn = true
        print("[AppState] session restored for \(user.email)")
        PushManager.shared.reportPendingToken()

        Task { @MainActor in
            do {
                let resp: APIResponse<UserProfile> = try await APIClient.shared.request("/me")
                if resp.code == 0, let fresh = resp.data {
                    // 刷新最新资料（金豆/昵称等可能已变化）
                    currentUser = fresh
                    if let json = try? JSONEncoder().encode(fresh) {
                        TokenStorage.shared.userJSON = String(data: json, encoding: .utf8)
                    }
                } else {
                    print("[AppState] /me rejected restored token, logging out")
                    logout()
                }
            } catch APIError.unauthorized {
                print("[AppState] restored token expired (401), logging out")
                logout()
            } catch {
                // 网络不可达等临时错误：保留本地登录态，不打断用户
                print("[AppState] /me validation unreachable: \(error.localizedDescription)")
            }
        }
    }

    func login(user: UserProfile, token: String) {
        self.currentUser = user
        self.isLoggedIn = true
        TokenStorage.shared.token = token
        if let json = try? JSONEncoder().encode(user) {
            TokenStorage.shared.userJSON = String(data: json, encoding: .utf8)
        }
        // 登录成功后上报缓存的推送 token（若 APNs token 已到手）
        PushManager.shared.reportPendingToken()
    }

    func updateNickname(_ nickname: String) async -> Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...32).contains(trimmed.count) else { return false }
        do {
            let resp: APIResponse<UserProfile> = try await APIClient.shared.request(
                "/me",
                method: .PATCH,
                body: ["nickname": trimmed]
            )
            guard resp.code == 0, let profile = resp.data else { return false }
            await MainActor.run {
                currentUser = profile
                if let json = try? JSONEncoder().encode(profile) {
                    TokenStorage.shared.userJSON = String(data: json, encoding: .utf8)
                }
            }
            return true
        } catch {
            print("[AppState] update nickname failed: \(error)")
            return false
        }
    }

    func logout() {
        self.currentUser = nil
        self.isLoggedIn = false
        TokenStorage.shared.clear()
        WebSocketClient.shared.disconnect()
    }

    func showToast(_ message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showToast = false
        }
    }

    func completeOnboarding() {
        // The language picked on the first-run screen was already persisted by
        // LanguageManager via `app_language`, so subsequent launches trust it.
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

struct UserProfile: Codable, Identifiable {
    let id: String
    var email: String
    var nickname: String
    var avatar: String
    var balance: Double
    var frozenBalance: Double
    var beansPurchased: Int
    var beansEarned: Int

    var beansTotal: Int { beansPurchased + beansEarned }

    enum CodingKeys: String, CodingKey {
        case id, email, nickname, avatar, balance
        case frozenBalance = "frozen_balance"
        case beansPurchased = "beans_purchased"
        case beansEarned = "beans_earned"
    }
}

import CoreLocation

/// 全局定位管理器：获取用户当前经纬度，供任务广场等需要"附近"能力的模块使用。
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    @Published var userLat: Double = 0
    @Published var userLng: Double = 0
    @Published var authorizationDenied = false

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 延迟启动定位，避免在 App 启动主线程同步弹授权框/初始化导致首屏白屏卡顿。
    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        // 过滤明显无效的坐标（0,0 通常是未定位状态）
        guard loc.coordinate.latitude != 0 || loc.coordinate.longitude != 0 else { return }
        userLat = loc.coordinate.latitude
        userLng = loc.coordinate.longitude
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationDenied = false
            manager.startUpdatingLocation()
        case .denied, .restricted:
            authorizationDenied = true
        default:
            break
        }
    }
}
