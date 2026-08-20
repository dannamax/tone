import Foundation
import Darwin

// MARK: - 子网自动发现（WiFi + USB 链路本地）

/// 获取设备当前活跃的 IP 地址及子网，用于在真机上自动定位同网段的 Mac 后端，
/// 无需手动填写 IP。同时支持 WiFi 和 USB 网络共享（169.254.x.x）两种场景。
struct NetworkDiscoverer {

    // MARK: - 获取本机 IP 与子网前缀

    /// 返回本机所有非回环、已启用的 IPv4 地址，**包括 169.254.x.x 链路本地地址**。
    /// 例如 WiFi 下返回 ["http://192.168.1.100:8080"]，
    /// USB 共享下返回 ["http://169.254.x.y:8080"]。
    static func localIPv4Interfaces() -> [String] {
        var result: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return result }
        var ptr = first
        while true {
            let flags = ptr.pointee.ifa_flags
            guard let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else {
                guard let next = ptr.pointee.ifa_next else { break }
                ptr = next
                continue
            }
            let isUp = (flags & UInt32(IFF_UP)) != 0
            let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0
            guard isUp, !isLoopback else {
                guard let next = ptr.pointee.ifa_next else { break }
                ptr = next
                continue
            }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: hostname)
            guard !ip.isEmpty, ip != "0.0.0.0" else {
                guard let next = ptr.pointee.ifa_next else { break }
                ptr = next
                continue
            }
            result.append("http://\(ip):8080")
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        freeifaddrs(ifaddr)
        return result
    }

    /// 从本机 IP 推导出同子网的候选 host 列表。
    /// - 普通 WiFi：扫描本机 IP 附近 ±range 范围 + 常见网关
    /// - 169.254.x.x 链路本地：扫描全 /24 子网（254 个候选），因为 Mac 的 host part 完全不可预测
    static func subnetCandidates(fromIP ip: String, range: Int = 255) -> [String] {
        guard let lastDot = ip.lastIndex(of: ".") else { return [] }
        let prefixStr = String(ip[..<lastDot])
            .replacingOccurrences(of: "http://", with: "")
        guard let hostPart = Int(ip[ip.index(after: lastDot)...].replacingOccurrences(of: ":8080", with: "")) else { return [] }

        let isLinkLocal = prefixStr.hasPrefix("169.254")

        var candidates: [String] = []

        if isLinkLocal {
            // 链路本地地址：Mac 的 host part 完全不可预测，扫描满 /24 范围
            let prioritySet: Set<Int> = [1, 2, 3, 64, 69, 100, 128, 200, 254]
            for p in prioritySet where p <= 254 {
                candidates.append("http://\(prefixStr).\(p):8080")
            }
            for i in 2...253 {
                if prioritySet.contains(i) { continue }
                candidates.append("http://\(prefixStr).\(i):8080")
            }
        } else {
            // 普通 WiFi / 有线网络：优先网关 + 本机附近
            let priorityIPs: Set<Int> = [1, 2, 3, 4, 5, 10, 20, 30, 254]
            for p in priorityIPs where p > 0 && p <= 254 {
                candidates.append("http://\(prefixStr).\(p):8080")
            }
            let lower = max(hostPart - range, 2)
            let upper = min(hostPart + range, 253)
            for i in lower...upper {
                if priorityIPs.contains(i) || i == hostPart { continue }
                candidates.append("http://\(prefixStr).\(i):8080")
            }
        }
        return candidates
    }

    /// 链路本地兜底扫描：基于设备自身的 169.254 地址生成同 /16 内其他 /24 的候选。
    /// 当设备同时有 WiFi + USB 接口时，已知的 link-local IP 可能不在 WiFi 接口的子网中，
    /// 此时用本方法补充扫描范围以防遗漏。
    static func linkLocalCandidates(fromLocalIPs ips: [String]) -> [String] {
        var result: [String] = []
        for ip in ips {
            let raw = ip.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: ":8080", with: "")
            guard raw.hasPrefix("169.254.") else { continue }
            // 获取设备的第三、四段
            let parts = raw.split(separator: ".").compactMap { Int($0) }
            guard parts.count == 4 else { continue }
            let deviceThird = parts[2]  // 设备所在的 /24 子网的三段
            // 扫描相邻 /24（±5 范围）
            let lower = max(deviceThird - 5, 1)
            let upper = min(deviceThird + 5, 254)
            for third in lower...upper where third != deviceThird {
                let commonLasts = [1, 2, 64, 100, 128, 200, 254]
                for last in commonLasts {
                    result.append("http://169.254.\(third).\(last):8080")
                }
            }
        }
        return result
    }

    // MARK: - 并发快速扫描

    /// 从候选地址列表中并发找到第一个可达的后端，最大并发 15 以减少网络压力。
    /// 每个 host 探测 0.5s 超时。
    static func discoverFirstReachable(from candidates: [String]) async -> String? {
        guard !candidates.isEmpty else { return nil }
        // 去重保序
        var seen = Set<String>()
        var unique: [String] = []
        for c in candidates {
            let normalized = c.replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: ":8080", with: "")
            if seen.insert(normalized).inserted {
                unique.append(c)
            }
        }
        var firstOK: String?
        let batchSize = 15
        var offset = 0
        while offset < unique.count, firstOK == nil {
            let batch = Array(unique[offset..<min(offset + batchSize, unique.count)])
            offset += batchSize
            await withTaskGroup(of: String?.self) { group in
                for host in batch {
                    group.addTask { await isHostReachableAsync(host) ? host : nil }
                }
                for await result in group {
                    if firstOK == nil, let host = result {
                        firstOK = host
                        group.cancelAll()
                    }
                }
            }
        }
        return firstOK
    }

    /// 探测某个 host 的 /health 是否可达（超时 0.5s），使用轻量 HEAD 请求。
    static func isHostReachableAsync(_ host: String) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 0.5
            cfg.waitsForConnectivity = false
            let sess = URLSession(configuration: cfg)
            guard let url = URL(string: "\(host)/health") else { cont.resume(returning: false); return }
            var req = URLRequest(url: url)
            req.httpMethod = "HEAD"
            sess.dataTask(with: req) { _, resp, _ in
                let ok = (resp as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
                cont.resume(returning: ok)
            }.resume()
        }
    }

    // MARK: - 一站式自动发现

    /// 自动发现后端地址：取本机 IP → 推导子网候选 → 并发扫描 → 返回首个可达地址。
    /// 涵盖 WiFi 和 USB 共享网络两种场景，无结果则返回 nil。
    static func autoDiscover() async -> String? {
        let localIps = localIPv4Interfaces()
        var candidates: [String] = []

        // 0. 历史缓存优先
        if let saved = UserDefaults.standard.string(forKey: "bounty_host"), !saved.isEmpty {
            candidates.append("http://\(saved):8080")
        }

        // 1. 从各个本机 IP 推导子网候选
        for localIP in localIps {
            let ipWithoutScheme = localIP.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: ":8080", with: "")
            let subnet = subnetCandidates(fromIP: localIP)
            candidates.append(contentsOf: subnet)
            print("[Discover] 本机 IP: \(ipWithoutScheme) → 子网候选 \(subnet.count) 个")
        }

        // 2. 补充链路本地相邻 /24 扫描（USB 场景兜底）
        if !localIps.isEmpty {
            let extraLL = linkLocalCandidates(fromLocalIPs: localIps)
            if !extraLL.isEmpty {
                print("[Discover] 补充链路本地相邻 /24 候选 \(extraLL.count) 个")
                candidates.append(contentsOf: extraLL)
            }
        }

        // 3. 如果仍然没有任何候选（罕见），兜底全量 169.254 常见段
        if candidates.isEmpty {
            print("[Discover] 无可用本机 IP，使用兜底候选")
            let commonThirds = [1, 27, 56, 59, 100, 101, 131, 200]
            for t in commonThirds {
                for last in [1, 2, 64, 69, 100, 128, 200, 254] {
                    candidates.append("http://169.254.\(t).\(last):8080")
                }
            }
        }

        print("[Discover] 共 \(candidates.count) 个候选地址，开始扫描...")
        let start = Date()
        if let found = await discoverFirstReachable(from: candidates) {
            let elapsed = Date().timeIntervalSince(start)
            print("[Discover] 发现后端: \(found)，耗时 \(String(format: "%.2f", elapsed))s")
            return found
        }
        print("[Discover] 扫描结束，未发现可达后端")
        return nil
    }
}
