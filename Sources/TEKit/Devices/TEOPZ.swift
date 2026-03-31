import Foundation

/// OP-Z specific serial protocol extensions
public enum TEOPZSerial {
    // OP-Z routing includes Blackfin DSP
    public static let blackfin: UInt8 = 0x02
    public static let appToBlackfin: UInt8 = 0x12
    public static let blackfinToApp: UInt8 = 0x21

    public enum Message: UInt8, Sendable {
        case greetingRequest = 0x05
        case greetingReply = 0x06
        case versionRequest = 0x07
        case versionReply = 0x08
        case powerModeRequest = 0x09
        case powerModeReply = 0x0A
        case powerModeAcknowledge = 0x0B
        case enableFactoryModeRequest = 0x0C
        case enableFactoryModeReply = 0x0D
        case profileData = 0x0E
        case controlProfileData = 0x0F
        case bfEnterDfu = 0x10
    }

    public enum PowerMode: UInt8, Sendable {
        case active = 0x01
        case standby = 0x02
        case charging = 0x03
        case lowBattery = 0x04
        case powerOff = 0x05
    }
}

@Observable
public final class TEOPZ: @unchecked Sendable {
    public let device: TEDevice
    private let parser = TESerialParser()

    public private(set) var powerMode: TEOPZSerial.PowerMode = .active
    public private(set) var firmwareVersion: String = ""
    public private(set) var isFactoryMode = false

    public init(device: TEDevice) {
        self.device = device
    }

    public func startListening() async {
        for await event in device.transport.events {
            if case .data(let data) = event {
                handleData(data)
            }
        }
    }

    private func handleData(_ data: Data) {
        guard let event = parser.parse(data) else { return }
        switch event {
        case .metadata(let meta):
            device.updateMetadata(TEDeviceMetadata(raw: meta))
            firmwareVersion = meta["sw_version"] ?? ""
        case .batteryLevel(let level, let charging, let pluggedIn):
            device.updateBattery(TEBatteryState(level: Int(level), isCharging: charging, isPluggedIn: pluggedIn))
        default:
            break
        }
    }

    private func send(_ msg: TESerialMessage) async throws {
        try await device.transport.send(msg.encoded)
    }

    public func greet() async throws {
        try await send(.requestMetadata())
    }

    public func requestVersion() async throws {
        let msg = TESerialMessage(routing: TESerial.orthoplayToApp, command: TEOPZSerial.Message.versionRequest.rawValue)
        try await send(msg)
    }

    public func requestPowerMode() async throws {
        let msg = TESerialMessage(routing: TESerial.orthoplayToApp, command: TEOPZSerial.Message.powerModeRequest.rawValue)
        try await send(msg)
    }

    public func setPowerMode(_ mode: TEOPZSerial.PowerMode) async throws {
        let msg = TESerialMessage(
            routing: TESerial.orthoplayToApp,
            command: TEOPZSerial.Message.powerModeRequest.rawValue,
            payload: Data([mode.rawValue])
        )
        try await send(msg)
    }

    public func requestBattery() async throws {
        try await send(.requestBattery())
    }

    public func ping() async throws {
        try await send(.ping())
    }
}
