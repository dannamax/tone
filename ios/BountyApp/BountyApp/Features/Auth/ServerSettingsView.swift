#if !PRODUCTION
import SwiftUI
import Network

/// 调试用：手动设置后端服务器地址，并显示真机当前的联通性测试结果，
/// 用于定位「真机连不上后端」到底是 host 错误还是网络不通（跨网段/客户端隔离）。
/// 上架（PRODUCTION）构建中整个文件被剔除，不会暴露给普通用户。
struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hostInput: String = ""
    @State private var testResult: String = L10n.serverNotTested
    @State private var isTesting = false
    @State private var savedHost: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.serverCurrentHost)) {
                    Text(AppConfig.baseHost)
                        .font(.system(size: 14, design: .monospaced))
                    Text(L10n.serverPersistHost + ": \(savedHost.isEmpty ? L10n.serverDefault : savedHost)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Section(header: Text(L10n.serverManualIP)) {
                    TextField(L10n.serverIPPlaceholder, text: $hostInput)
                        .font(.system(size: 14, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button(L10n.serverSaveApply) {
                        applyHost(hostInput)
                    }
                    .disabled(hostInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section(header: Text(L10n.serverConnectivity)) {
                    Button {
                        testConnection()
                    } label: {
                        if isTesting {
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text(L10n.serverTestConn + " \(AppConfig.baseHost)/health")
                        }
                    }
                    Text(testResult)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Section(header: Text(L10n.serverHint), footer: Text(L10n.serverHintFooter)) {
                    EmptyView()
                }
            }
            .navigationTitle(L10n.serverSettingsTitle)
            .navigationBarItems(trailing: Button(L10n.done) { dismiss() })
            .onAppear {
                savedHost = UserDefaults.standard.string(forKey: "bounty_host") ?? ""
                hostInput = savedHost
            }
        }
    }

    private func applyHost(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        var host = trimmed
        if let range = host.range(of: ":") {
            host = String(host[..<range.lowerBound])
        }
        AppConfig.setCustomHost(host)
        APIClient.shared.applyDiscoveredHost("http://\(host):8080")
        savedHost = host
        testResult = String(format: L10n.serverSavedHostFmt, "http://\(host):8080")
    }

    private func testConnection() {
        isTesting = true
        testResult = L10n.serverTesting
        let urlString = "\(AppConfig.baseHost)/health"
        guard let url = URL(string: urlString) else {
            testResult = L10n.serverAddrParseFail
            isTesting = false
            return
        }
        // 后台探测，不阻塞主线程
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        URLSession.shared.dataTask(with: req) { _, resp, err in
            DispatchQueue.main.async {
                isTesting = false
                if let e = err {
                    let code = (e as NSError).code
                    let hint: String
                    switch code {
                    case NSURLErrorTimedOut: hint = L10n.serverTimeoutDetail
                    case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost: hint = L10n.serverCannotConnectDetail
                    case NSURLErrorNotConnectedToInternet: hint = L10n.serverNoInternetDetail
                    default: hint = String(format: L10n.serverErrorCodeFmt, code)
                    }
                    testResult = "❌ \(hint)"
                } else if let http = resp as? HTTPURLResponse {
                    testResult = "✅ \(String(format: L10n.serverConnSuccessFmt, http.statusCode))"
                } else {
                    testResult = "❓ \(L10n.serverUnknown)"
                }
            }
        }.resume()
    }
}
#endif
