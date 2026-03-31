import Foundation

public enum TEDeviceType: String, Sendable, CaseIterable {
    case ob4 = "OB-4"
    case od11 = "OD-11"
    case opz = "OP-Z"
    case tp7 = "TP-7"
    case ep133 = "EP-133"
    case koII = "KO-II"
    case unknown
}

public enum TEConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

@Observable
public final class TEDevice: Identifiable {
    public let id: String
    public let name: String
    public let type: TEDeviceType
    public let transport: any TETransport

    public private(set) var connectionState: TEConnectionState = .disconnected
    public private(set) var metadata: TEDeviceMetadata?
    public private(set) var battery: TEBatteryState?

    public init(id: String, name: String, type: TEDeviceType, transport: any TETransport) {
        self.id = id
        self.name = name
        self.type = type
        self.transport = transport
    }

    public func connect() async throws {
        connectionState = .connecting
        try await transport.connect()
        connectionState = .connected
    }

    public func disconnect() async {
        connectionState = .disconnecting
        await transport.disconnect()
        connectionState = .disconnected
    }

    func updateMetadata(_ meta: TEDeviceMetadata) {
        self.metadata = meta
    }

    func updateBattery(_ state: TEBatteryState) {
        self.battery = state
    }
}

public struct TEDeviceMetadata: Sendable {
    public var product: String?
    public var serialNumber: String?
    public var softwareVersion: String?
    public var mode: String?
    public var raw: [String: String]

    public init(raw: [String: String]) {
        self.raw = raw
        self.product = raw["product"]
        self.serialNumber = raw["serial_number"] ?? raw["serial"]
        self.softwareVersion = raw["sw_version"] ?? raw["version"]
        self.mode = raw["mode"]
    }
}

public struct TEBatteryState: Sendable {
    public let level: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool

    public init(level: Int, isCharging: Bool, isPluggedIn: Bool) {
        self.level = level
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
    }
}
