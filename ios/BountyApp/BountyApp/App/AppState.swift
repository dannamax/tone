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
    }

    func login(user: UserProfile, token: String) {
        self.currentUser = user
        self.isLoggedIn = true
        TokenStorage.shared.token = token
        if let json = try? JSONEncoder().encode(user) {
            TokenStorage.shared.userJSON = String(data: json, encoding: .utf8)
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
    var publishQuota: Int
    var usedQuota: Int

    enum CodingKeys: String, CodingKey {
        case id, email, nickname, avatar, balance
        case frozenBalance = "frozen_balance"
        case publishQuota = "publish_quota"
        case usedQuota = "used_quota"
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
