import Foundation

class WebSocketClient: ObservableObject {
    static let shared = WebSocketClient()
    private var task: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    @Published var isConnected = false

    var onMessage: ((String) -> Void)?

    func connect(userID: String) {
        disconnect()
        // 模拟器下 wsBaseURL 已是 127.0.0.1，真机用局域网 IP
        guard let url = URL(string: "\(AppConfig.wsBaseURL)?user_id=\(userID)") else { return }
        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        receiveMessage()
        startPing()
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
    }

    private func receiveMessage() {
        task?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        self?.onMessage?(text)
                    }
                default:
                    break
                }
                self?.receiveMessage()
            case .failure:
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.receiveMessage()
                }
            }
        }
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.task?.sendPing { _ in }
        }
    }
}
