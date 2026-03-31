import Foundation

public enum TETransportState: Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

public protocol TETransport: AnyObject, Sendable {
    var state: TETransportState { get }
    var events: AsyncStream<TETransportEvent> { get }
    func connect() async throws
    func disconnect() async
    func send(_ data: Data) async throws
}

public enum TETransportEvent: Sendable {
    case connected
    case disconnected(Error?)
    case data(Data)
}
