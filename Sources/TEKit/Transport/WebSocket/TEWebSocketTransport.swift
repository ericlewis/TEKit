import Foundation
import Network

public final class TEWebSocketTransport: NSObject, TETransport, @unchecked Sendable {
    public private(set) var state: TETransportState = .disconnected

    private let url: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var continuation: AsyncStream<TETransportEvent>.Continuation?

    public lazy var events: AsyncStream<TETransportEvent> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    public init(url: URL) {
        self.url = url
    }

    public init(host: String, port: Int = 80) {
        self.url = URL(string: "ws://\(host):\(port)/")!
    }

    public func connect() async throws {
        state = .connecting
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        state = .connected
        continuation?.yield(.connected)
        receiveLoop()
    }

    public func disconnect() async {
        state = .disconnecting
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        state = .disconnected
        continuation?.yield(.disconnected(nil))
    }

    public func send(_ data: Data) async throws {
        guard let task = webSocketTask else { throw TEWebSocketError.notConnected }
        let string = String(data: data, encoding: .utf8) ?? ""
        try await task.send(.string(string))
    }

    public func sendJSON(_ action: String, params: [String: Any] = [:]) async throws {
        var message: [String: Any] = ["action": action]
        for (k, v) in params { message[k] = v }
        let data = try JSONSerialization.data(withJSONObject: message)
        guard let task = webSocketTask else { throw TEWebSocketError.notConnected }
        try await task.send(.string(String(data: data, encoding: .utf8)!))
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self?.continuation?.yield(.data(data))
                    }
                case .data(let data):
                    self?.continuation?.yield(.data(data))
                @unknown default:
                    break
                }
                self?.receiveLoop()
            case .failure(let error):
                self?.state = .disconnected
                self?.continuation?.yield(.disconnected(error))
            }
        }
    }
}

public enum TEWebSocketError: Error, Sendable {
    case notConnected
    case invalidURL
}

// MARK: - Bonjour Browser for OD-11

public final class TEBonjourBrowser: @unchecked Sendable {
    private var browser: NWBrowser?
    private let onDeviceFound: @Sendable (TEDevice) -> Void

    public init(onDeviceFound: @escaping @Sendable (TEDevice) -> Void) {
        self.onDeviceFound = onDeviceFound
    }

    public func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: "_od11._tcp", domain: nil), using: params)

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            for result in results {
                if case .service(let name, _, _, _) = result.endpoint {
                    self?.resolveEndpoint(result.endpoint, name: name)
                }
            }
        }
        browser?.start(queue: .main)
    }

    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    private func resolveEndpoint(_ endpoint: NWEndpoint, name: String) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let path = connection.currentPath,
                   let endpoint = path.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {
                    let transport = TEWebSocketTransport(host: "\(host)", port: Int(port.rawValue))
                    let device = TEDevice(
                        id: "od11-\(name)",
                        name: name,
                        type: .od11,
                        transport: transport
                    )
                    self?.onDeviceFound(device)
                }
                connection.cancel()
            }
        }
        connection.start(queue: .main)
    }
}
