import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(Int)
    case decodingFailed
    case unauthorized
    case networkError(Error)

    /// 将底层网络错误转换为对用户友好的文案
    var friendlyMessage: String {
        switch self {
        case .invalidURL:
            return L10n.loginInvalidURL
        case .requestFailed(let code):
            return String(format: L10n.apiServerErrorFmt, code)
        case .decodingFailed:
            return L10n.loginDecodeFailed
        case .unauthorized:
            return L10n.loginAuthFailed
        case .networkError(let err):
            let ns = err as NSError
            if ns.domain == NSURLErrorDomain {
                switch ns.code {
                case NSURLErrorTimedOut:
                    return L10n.apiTimeout
                case NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost,
                     NSURLErrorNetworkConnectionLost, NSURLErrorCannotFindHost:
                    return L10n.apiCannotConnect
                case NSURLErrorCancelled:
                    return L10n.apiCancelled
                default:
                    return String(format: L10n.apiNetworkErrorFmt, ns.code)
                }
            }
            return L10n.apiNetworkError
        }
    }
}

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

struct PaginatedResponse<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
    let page: Int
    let size: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case items, total, page, size
        case totalPages = "total_pages"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? container.decode([T].self, forKey: .items)) ?? []
        total = (try? container.decode(Int.self, forKey: .total)) ?? 0
        page = (try? container.decode(Int.self, forKey: .page)) ?? 1
        size = (try? container.decode(Int.self, forKey: .size)) ?? 20
        totalPages = (try? container.decode(Int.self, forKey: .totalPages)) ?? 0
    }
}

/// 网络环境配置：开发期区分模拟器与真机。
///
/// **真机自动发现策略**：
/// 1. 如果已通过 ServerSettings 或历史运行缓存过 host，直接用缓存（零延迟）
/// 2. 未缓存时：本机 IP → 推导子网 → 并发扫描 `/health`（首批 < 3s 出结果）
/// 3. 扫描结果持久化到 UserDefaults，下次启动秒开
/// 4. 网络切换时 NetworkMonitor 会触发 UDP 发现 + 子网扫描自愈
///
/// 无需再手动填写 IP。
enum AppConfig {

    /// Production build flag. When set (via the `PRODUCTION` Swift compiler flag
    /// in the Release/App Store build configuration), the app connects to a fixed
    /// public HTTPS backend and disables the LAN auto-discovery / debug server
    /// settings used during development.
    #if PRODUCTION
    static let isProduction = true
    #else
    static let isProduction = false
    #endif

    /// Public backend base URL used in production builds.
    /// Injected via Info.plist key `BackendBaseHost` so the domain can be changed
    /// without recompiling. Falls back to the real domain if the key is missing.
    static let productionBaseHost: String = {
        Bundle.main.infoDictionary?["BackendBaseHost"] as? String
            ?? "https://api.gotseeker.com"
    }()

    /// Privacy policy page shown in the first-launch consent sheet and profile.
    /// Injected via Info.plist key `PrivacyPolicyURL`.
    static let privacyPolicyURL: String = {
        Bundle.main.infoDictionary?["PrivacyPolicyURL"] as? String
            ?? "https://gotseeker.com/privacy"
    }()

    /// Terms of service page shown in the first-launch consent sheet and profile.
    /// Injected via Info.plist key `TermsOfServiceURL`.
    static let termsOfServiceURL: String = {
        Bundle.main.infoDictionary?["TermsOfServiceURL"] as? String
            ?? "https://gotseeker.com/terms"
    }()

    /// 自动发现是否已完成（由 AppState 启动时触发）
    private(set) static var discoveryCompleted = false

    /// 后台自动发现 Task，可被 await 等待完成
    private static var discoveryTask: Task<String?, Never>?

    /// 后端服务地址（不含路径），例如 http://192.168.1.20:8080
    /// 优先级：环境变量 > UserDefaults 缓存 > 自动发现结果
    /// 注意：真机上无缓存且未发现时返回空字符串，绝不用 127.0.0.1 兜底（指向 iPhone 自身）。
    static var baseHost: String {
        #if targetEnvironment(simulator)
        // 模拟器（含 Release/PRODUCTION 配置）始终连本机后端，便于真机前联调。
        return "http://127.0.0.1:8080"
        #elseif PRODUCTION
        // 上架版本直接连公网 HTTPS 后端，不做局域网发现。
        return productionBaseHost
        #else
        if let env = ProcessInfo.processInfo.environment["BOUNTY_HOST"], !env.isEmpty {
            return "http://\(env):8080"
        }
        if let saved = UserDefaults.standard.string(forKey: "bounty_host"), !saved.isEmpty {
            return "http://\(saved):8080"
        }
        // 真机上绝不回退到 127.0.0.1（指向 iPhone 自身，永远不可达）
        // 返回空字符串，request() 会快速失败并提示用户手动设置
        return ""
        #endif
    }

    /// 持久化自定义后端 IP（不带端口）
    static func setCustomHost(_ host: String) {
        let h = host.replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: ":8080", with: "")
        UserDefaults.standard.set(h, forKey: "bounty_host")
    }

    /// 清除持久化缓存（网络环境变化时调用，强制重新发现）
    static func clearCachedHost() {
        UserDefaults.standard.removeObject(forKey: "bounty_host")
        discoveryCompleted = false
    }

    /// 启动后台自动发现（AppState 初始化时调用一次，幂等）
    static func launchDiscovery() {
        guard discoveryTask == nil else { return }
        discoveryTask = Task { await _doDiscovery() }
    }

    /// 等待自动发现完成（最多 5 秒），APIClient 发请求前调用
    static func waitForDiscovery() async {
        if discoveryCompleted { return }
        // 如果没启动过，则立即启动
        if discoveryTask == nil { launchDiscovery() }
        // 轮询等待，最多 5 秒（避免 discovery 卡住时永久阻塞）
        let deadline = Date().addingTimeInterval(5)
        while !discoveryCompleted && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms 间隔
        }
        if !discoveryCompleted {
            NSLog("[AppConfig] 自动发现超时（5s），继续使用 baseHost 兜底")
        } else {
            NSLog("[AppConfig] 自动发现完成")
        }
    }

    private static func _doDiscovery() async -> String? {
        defer { discoveryCompleted = true }
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8080"
        #else
        // 验证缓存 host 是否仍然可达；连续 3 次不可达才清除，避免重启瞬间误删
        if let saved = UserDefaults.standard.string(forKey: "bounty_host"), !saved.isEmpty {
            let cachedURL = "http://\(saved):8080"
            if await NetworkDiscoverer.isHostReachableAsync(cachedURL) {
                UserDefaults.standard.set(0, forKey: "bounty_host_fail_count")
                NSLog("[AppConfig] 缓存地址 %@ 仍可达，跳过扫描", cachedURL)
                return nil
            }
            let failCount = UserDefaults.standard.integer(forKey: "bounty_host_fail_count") + 1
            UserDefaults.standard.set(failCount, forKey: "bounty_host_fail_count")
            if failCount < 3 {
                NSLog("[AppConfig] 缓存地址 %@ 第%d次不可达（需3次才清除），继续使用缓存", cachedURL, failCount)
                return nil
            }
            NSLog("[AppConfig] 缓存地址 %@ 连续%d次不可达，清除并重新扫描", cachedURL, failCount)
            UserDefaults.standard.removeObject(forKey: "bounty_host")
            UserDefaults.standard.removeObject(forKey: "bounty_host_fail_count")
        }
        guard let found = await NetworkDiscoverer.autoDiscover() else {
            NSLog("[AppConfig] 自动扫描未发现后端")
            return nil
        }
        let h = found.replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: ":8080", with: "")
        UserDefaults.standard.set(h, forKey: "bounty_host")
        await MainActor.run { APIClient.shared.applyDiscoveredHost(found) }
        NSLog("[AppConfig] 自动发现后端地址: %@", found)
        return found
        #endif
    }

    static var apiBaseURL: String { baseHost + "/api/v1" }
    static var wsBaseURL: String { baseHost.replacingOccurrences(of: "http", with: "ws") + "/ws" }

    /// 候选后端地址池：用于请求前自动探活自愈。
    /// 优先使用本机 IP 推导的子网候选（WiFi），再补充 USB 链路本地 + 兜底静态段。
    /// 真机通过 USB 网络共享连 Mac 时，169.254.x.x 每次重连都会变，
    /// 因此枚举常见链路本地地址做兜底探测。
    static var candidateHosts: [String] {
        var set = Set<String>()

        // 0. 已缓存 host（最高先级候选）
        if let saved = UserDefaults.standard.string(forKey: "bounty_host"), !saved.isEmpty {
            set.insert("http://\(saved):8080")
        }
        if let env = ProcessInfo.processInfo.environment["BOUNTY_HOST"], !env.isEmpty {
            set.insert("http://\(env):8080")
        }

        // 1. 本机 IP 子网候选（WiFi 场景，动态计算）
        let localIps = NetworkDiscoverer.localIPv4Interfaces()
        for localIP in localIps {
            let subnetCandidates = NetworkDiscoverer.subnetCandidates(fromIP: localIP)
            for c in subnetCandidates { set.insert(c) }
        }

        // 2. USB 共享网络链路本地地址段兜底
        let linkLocalCands = NetworkDiscoverer.linkLocalCandidates(fromLocalIPs: localIps)
        for c in linkLocalCands { set.insert(c) }

        // 3. 回环（仅在模拟器加入候选；真机上 127.0.0.1 指向 iPhone 自身，永远不可达）
        #if targetEnvironment(simulator)
        set.insert("http://127.0.0.1:8080")
        set.insert("http://localhost:8080")
        #endif

        return Array(set)
    }

    // MARK: - 自动发现（AppState 启动时调用一次）

    /// 网络切换后重新自动发现
    static func rediscoverOnNetworkChange() {
        discoveryCompleted = false
        discoveryTask = Task { await _doDiscovery() }
    }
}

/// Network client singleton. Marked `@unchecked Sendable` because it is a
/// long-lived singleton accessed from concurrent contexts (the
/// `withCheckedThrowingContinuation` completion handler in `request` captures
/// `self`). Internal mutable state (`currentTask`) is guarded by `taskLock`,
/// so it is safe to share across actors; the unchecked conformance silences
/// the Swift 6 strict-concurrency checker that would otherwise crash at
/// runtime in Release builds.
final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    /// UI 测试模式标记：启动时检测 -UITestMode 参数。开启后网络请求直接返回
    /// 内存 mock 数据，无需真实后端，便于自动化跑通登录等核心流程。
    static let isUITestMode: Bool = ProcessInfo.processInfo.arguments.contains("-UITestMode")

    /// 后端基准地址，可被自动发现逻辑更新（换局域网自愈）
    private(set) var baseURL: String = AppConfig.apiBaseURL

    /// 当前实际生效的后端 origin（如 http://192.168.1.9:8080 或 https://api.gotseeker.com）。
    /// 由 baseURL（.../api/v1）去掉路径得到。静态资源（上传图片等）URL 拼接
    /// 必须使用它而不是 AppConfig.baseHost，保证与 API 请求同源、自动发现一致。
    public var currentOrigin: String {
        if let r = baseURL.range(of: "/api/v1") {
            return String(baseURL[..<r.lowerBound])
        }
        return baseURL
    }

    private let session: URLSession
    private let decoder: JSONDecoder
    /// 当前进行中的请求任务，用于网络切换时主动取消（方案A）
    private var currentTask: URLSessionDataTask?
    private let taskLock = NSLock()

    private init() {
        let config = URLSessionConfiguration.default
        // 连接超时短，快速失败避免白屏长时间等待；请求超时适中
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    /// 应用自动发现到的后端地址（持久化到 UserDefaults，下次启动直接复用）
    public func applyDiscoveredHost(_ host: String) {
        let h = host.replacingOccurrences(of: "http://", with: "")
        let base = "http://\(h)"
        let newBase = base + "/api/v1"
        if newBase != baseURL {
            baseURL = newBase
            AppConfig.setCustomHost(h)
            print("[APIClient] 自动发现后端地址: \(base)")
        }
    }

    var token: String? {
        get { TokenStorage.shared.token }
    }

    /// 取消进行中的请求（网络切换时由 NetworkMonitor 调用）
    func cancelCurrentRequest() {
        taskLock.lock()
        currentTask?.cancel()
        currentTask = nil
        taskLock.unlock()
    }

    /// 关键请求前的兜底：探活当前 host，若不通则对一组候选 host 并发探测，
    /// 自动切换到第一个可连通的地址（真机通过 USB 共享网络时链路本地地址会变，
    /// 此逻辑可在换网络/重插 USB 后自愈，无需手动改 host）。
    /// 注意：必须 async（非阻塞），否则在 @MainActor 上用信号量会卡死主线程。
    func ensureReachableHost() async {
        let current = baseURL
        let currentHost = stripAPIPath(current)
        let currentReachable = await isReachable(currentHost)
        if currentReachable { return }

        NSLog("[APIClient] 当前 host %@ 不可达，尝试候选地址自愈", currentHost)
        let candidates = AppConfig.candidateHosts.filter { $0 != currentHost }
        guard !candidates.isEmpty else {
            NSLog("[APIClient] 无候选地址可用")
            return
        }
        var firstOK: String?
        // 并发探测候选地址，取第一个连通的并取消其余任务
        await withTaskGroup(of: String?.self) { group in
            for host in candidates {
                group.addTask { await self.isReachable(host) ? host : nil }
            }
            for await result in group {
                if firstOK == nil, let host = result {
                    firstOK = host
                    group.cancelAll()
                }
            }
        }
        if let ok = firstOK {
            NSLog("[APIClient] 自愈成功，切换到 %@", ok)
            await MainActor.run {
                self.baseURL = ok + "/api/v1"
                let h = ok.replacingOccurrences(of: "http://", with: "")
                AppConfig.setCustomHost(h)
            }
        } else {
            NSLog("[APIClient] 未找到任何可达候选地址")
        }
    }

    /// 从带 /api/v1 后缀的地址中提取纯 host（scheme+host+port）
    private func stripAPIPath(_ urlStr: String) -> String {
        urlStr.replacingOccurrences(of: "/api/v1", with: "")
    }

    /// 非阻塞探活某个 host 的 /health（1.5s 超时）。
    /// host 应为 scheme+host+port 形式（如 http://127.0.0.1:8080），不含业务路径。
    private func isReachable(_ host: String) async -> Bool {
        guard !host.isEmpty, !host.hasSuffix(":") else { return false }
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let probe = URLSession(configuration: {
                let c = URLSessionConfiguration.default
                c.timeoutIntervalForRequest = 1.5
                c.waitsForConnectivity = false
                return c
            }())
            guard let url = URL(string: "\(host)/health"), url.host != nil else { cont.resume(returning: false); return }
            probe.dataTask(with: url) { _, resp, _ in
                let ok = (resp as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
                cont.resume(returning: ok)
            }.resume()
        }
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Any? = nil,
        requiresAuth: Bool = true
    ) async throws -> APIResponse<T> {
        // UI 测试模式：直接返回内存中的 mock 响应，免去对真实后端的依赖。
        // 仅在启动时检测到 -UITestMode 参数才生效，不影响生产逻辑。
        if APIClient.isUITestMode {
            return try Self.mockResponse(for: path, as: T.self)
        }

        // 等待自动发现完成（最多 5s），避免请求发到占位地址 127.0.0.1
        await AppConfig.waitForDiscovery()

        // 真机绝对防御：若仍指向本机回环，说明自动发现/缓存均失败，
        // 直接失败并提示手动设置，避免 30s 超时白等。
        #if !targetEnvironment(simulator)
        if baseURL.contains("127.0.0.1") || baseURL.contains("localhost") {
            NSLog("[APIClient] 真机 baseURL 指向本机回环，拒绝请求: %@", baseURL)
            throw APIError.networkError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost, userInfo: [NSLocalizedDescriptionKey: L10n.serverSetHint]))
        }
        #endif

        // 必须在构造 URL 之前执行自愈，否则 url 指向的还是旧地址
        await ensureReachableHost()

        // 兜底：自愈后仍然不可达时直接失败，避免 30s 超时白等
        let reachableHost = stripAPIPath(baseURL)
        let hostEmpty = reachableHost.isEmpty
        let hostReachable = await isReachable(reachableHost)
        if hostEmpty || !hostReachable {
            NSLog("[APIClient] 无可用后端地址，直接失败: '%@'", reachableHost)
            throw APIError.networkError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost, userInfo: [NSLocalizedDescriptionKey: L10n.serverSetHint]))
        }

        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Tell the backend which language to use so server-side messages
        // (errors, task statuses, notifications, wallet hints) stay consistent
        // with the in-app UI language selected by the user.
        request.setValue(LanguageManager.shared.currentCode, forHTTPHeaderField: "Accept-Language")

        if requiresAuth, let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let deviceID = TokenStorage.shared.deviceID {
            request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        }

        if let body = body, method != "GET" {
            if let encodable = body as? Encodable {
                request.httpBody = try JSONEncoder().encode(AnyEncodable(encodable))
            } else {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
        }

        var task: URLSessionDataTask?
        do {
            let (data, response) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(Data, URLResponse), Error>) in
                task = session.dataTask(with: request) { [weak self] data, response, error in
                    self?.taskLock.lock()
                    if self?.currentTask === task { self?.currentTask = nil }
                    self?.taskLock.unlock()

                    if let error = error {
                        cont.resume(throwing: APIError.networkError(error))
                    } else if let data = data, let response = response {
                        cont.resume(returning: (data, response))
                    } else {
                        cont.resume(throwing: APIError.networkError(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown)))
                    }
                }
                self.taskLock.lock()
                self.currentTask = task
                self.taskLock.unlock()
                task?.resume()
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.requestFailed(0)
            }

            let bodyStr = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            NSLog("[APIClient] %@ %@ -> %d, body: %@", method, url.absoluteString, httpResponse.statusCode, bodyStr)

            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            do {
                return try decoder.decode(APIResponse<T>.self, from: data)
            } catch {
                NSLog("[APIClient] decode error: %@", error.localizedDescription)
                if httpResponse.statusCode >= 400 {
                    throw APIError.requestFailed(httpResponse.statusCode)
                }
                throw APIError.decodingFailed
            }
        } catch {
            // 取消或网络错误统一包装，便于上层识别"网络已切换"
            if let apiErr = error as? APIError {
                if case .networkError(let err) = apiErr {
                    NSLog("[APIClient] 请求失败: %@", err.localizedDescription)
                }
                throw apiErr
            }
            NSLog("[APIClient] 请求失败: %@", error.localizedDescription)
            throw APIError.networkError(error)
        }
    }
}

// MARK: - Network Monitor

import Network

extension Notification.Name {
    static let networkDidSwitch = Notification.Name("com.seeker.networkDidSwitch")
    static let networkDidDisconnect = Notification.Name("com.seeker.networkDidDisconnect")
}

/// 监听网络路径变化（WiFi/蜂窝切换、断网重连）。
/// 切换时主动取消进行中的请求并提示用户重试，同时触发局域网后端自动发现（方案A+B）。
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected = true
    @Published var interfaceType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.seeker.networkmonitor")
    private var previousPath: NWPath?
    private var discoverySocket: CFSocket?
    /// 自动发现后台监听的运行标记，避免重复启动
    private let discoveryLock = NSLock()
    private var discoveryRunning = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let wasConnected = self.previousPath?.status == .satisfied
            let nowConnected = path.status == .satisfied
            let prevType = self.previousPath?.availableInterfaces.first?.type
            let nowType = path.availableInterfaces.first?.type

            let changed = self.previousPath == nil
                || wasConnected != nowConnected
                || prevType != nowType

            self.previousPath = path

            DispatchQueue.main.async {
                self.isConnected = nowConnected
                self.interfaceType = nowType
            }

            if changed && self.previousPath != nil {
                APIClient.shared.cancelCurrentRequest()
                if wasConnected && nowConnected && prevType != nowType {
                    NotificationCenter.default.post(name: .networkDidSwitch, object: nil)
                } else if !nowConnected {
                    NotificationCenter.default.post(name: .networkDidDisconnect, object: nil)
                }
                // 网络变化后重新发现局域网后端（换 WiFi 自愈）
                self.startDiscovery()
            }
        }
        monitor.start(queue: queue)
        // 启动时也尝试一次发现
        startDiscovery()
    }

    /// 启动持续 UDP 广播监听：后端每 3 秒广播一次，App 常驻接收，
    /// 一旦收到即更新后端地址（换 WiFi 自愈）。相比只监听 4 秒，
    /// 持续监听可避免启动时机错过首包导致一直用旧 host。
    private func startDiscovery() {
        discoveryLock.lock()
        if discoveryRunning { discoveryLock.unlock(); return }
        discoveryRunning = true
        discoveryLock.unlock()

        DispatchQueue.global(qos: .background).async { [weak self] in
            let port = UInt16(18999)
            // 显式绑定 IPv4 通配地址 0.0.0.0，确保能接收来自 WiFi 与 USB 链路本地
            // 子网的 UDP 广播（AI_PASSIVE 在 macOS 上可能只绑定 IPv6）。
            var hints = addrinfo(ai_flags: AI_PASSIVE, ai_family: AF_INET, ai_socktype: SOCK_DGRAM, ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
            var res: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo("0.0.0.0", "\(port)", &hints, &res) == 0, let first = res else {
                self?.discoveryLock.lock(); self?.discoveryRunning = false; self?.discoveryLock.unlock()
                return
            }
            defer { freeaddrinfo(res) }

            let sock = socket(first.pointee.ai_family, first.pointee.ai_socktype, first.pointee.ai_protocol)
            guard sock >= 0 else {
                self?.discoveryLock.lock(); self?.discoveryRunning = false; self?.discoveryLock.unlock()
                return
            }
            defer { close(sock) }

            var yes: Int32 = 1
            setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
            guard bind(sock, first.pointee.ai_addr, first.pointee.ai_addrlen) == 0 else {
                self?.discoveryLock.lock(); self?.discoveryRunning = false; self?.discoveryLock.unlock()
                return
            }

            var buffer = [UInt8](repeating: 0, count: 256)
            var lastApply = Date.distantPast
            while true {
                var addr = sockaddr_storage()
                var addrLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
                let n = withUnsafeMutablePointer(to: &addr) { ptr in
                    recvfrom(sock, &buffer, buffer.count, 0, ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }, &addrLen)
                }
                guard n > 0 else { continue }
                let data = Data(bytes: buffer, count: n)
                if let msg = String(data: data, encoding: .utf8),
                   msg.hasPrefix("SEEKER-DISCOVER|") {
                    let host = String(msg.dropFirst("SEEKER-DISCOVER|".count))
                    // 同一地址 1 秒内不重复处理，避免刷屏
                    if Date().timeIntervalSince(lastApply) > 1 {
                        lastApply = Date()
                        DispatchQueue.main.async {
                            APIClient.shared.applyDiscoveredHost(host)
                        }
                    }
                }
            }
        }
    }

    deinit {
        monitor.cancel()
    }
}

struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

class TokenStorage {
    static let shared = TokenStorage()
    private let defaults = UserDefaults.standard

    var token: String? {
        get { defaults.string(forKey: "auth_token") }
        set { defaults.set(newValue, forKey: "auth_token") }
    }

    var deviceID: String? {
        get { defaults.string(forKey: "device_id") }
        set { defaults.set(newValue, forKey: "device_id") }
    }

    var userJSON: String? {
        get { defaults.string(forKey: "user_json") }
        set { defaults.set(newValue, forKey: "user_json") }
    }

    func clear() {
        defaults.removeObject(forKey: "auth_token")
        defaults.removeObject(forKey: "user_json")
    }
}

// MARK: - UI Test Mock

extension APIClient {
    /// 为 UI 测试提供内存 mock 响应，覆盖登录与用户资料等关键接口。
    static func mockResponse<T: Decodable>(for path: String, as type: T.Type) throws -> APIResponse<T> {
        let payload: Any
        if path.contains("/auth/send-code") {
            payload = NSNull()
        } else if path.contains("/auth/login") {
            payload = [
                "access_token": "mock-token-uitest",
                "refresh_token": "mock-refresh",
                "expires_in": 86400,
                "user": [
                    "id": "u1",
                    "email": "tester@example.com",
                    "nickname": "Tester",
                    "avatar": "",
                    "role": "seeker",
                    "balance": 0,
                    "frozen_balance": 0,
                    "beans_purchased": 5,
                    "beans_earned": 0,
                    "created_at": "2026-01-01T00:00:00Z"
                ]
            ]
        } else if path.contains("/user/me") || path.contains("/profile") {
            payload = [
                "id": "u1",
                "email": "tester@example.com",
                "nickname": "Tester",
                "avatar": "",
                "role": "seeker",
                "balance": 0,
                "frozen_balance": 0,
                "beans_purchased": 5,
                "beans_earned": 0,
                "created_at": "2026-01-01T00:00:00Z"
            ]
        } else {
            // 列表/详情等接口统一返回空数组包装
            payload = []
        }

        let wrapper: [String: Any] = ["code": 200, "message": "ok", "data": payload]
        let data = try JSONSerialization.data(withJSONObject: wrapper)
        let decoded = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        return decoded
    }
}
