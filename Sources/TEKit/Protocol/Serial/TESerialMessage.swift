import Foundation

public struct TESerialMessage: Sendable {
    public let routing: UInt8
    public let command: UInt8
    public let payload: Data

    public init(routing: UInt8, command: UInt8, payload: Data = Data()) {
        self.routing = routing
        self.command = command
        self.payload = payload
    }

    public var encoded: Data {
        var data = Data([routing, command])
        data.append(payload)
        return data
    }

    // MARK: - Factory Methods

    public static func ping() -> TESerialMessage {
        TESerialMessage(routing: TESerial.orthoplayToApp, command: TESerial.Message.ping.rawValue)
    }

    public static func requestMetadata() -> TESerialMessage {
        TESerialMessage(routing: TESerial.orthoplayToApp, command: TESerial.Message.readMetadataRequest.rawValue)
    }

    public static func requestBattery() -> TESerialMessage {
        TESerialMessage(routing: TESerial.orthoplayToApp, command: TESerial.Message.batteryLevelRequest.rawValue)
    }

    public static func userAction(_ action: TESerial.UserAction, payload: Data = Data()) -> TESerialMessage {
        var data = Data([action.rawValue])
        data.append(payload)
        return TESerialMessage(routing: TESerial.orthoplayToApp, command: TESerial.Message.userAction.rawValue, payload: data)
    }

    public static func play() -> TESerialMessage { userAction(.play) }
    public static func pause() -> TESerialMessage { userAction(.pause) }
    public static func togglePause() -> TESerialMessage { userAction(.togglePause) }
    public static func nextTrack() -> TESerialMessage { userAction(.nextTrack) }
    public static func prevTrack() -> TESerialMessage { userAction(.prevTrack) }
    public static func knockKnock() -> TESerialMessage { userAction(.knockKnock) }
    public static func connected() -> TESerialMessage { userAction(.connected) }

    public static func changeVolume(_ volume: UInt8, color: TESerial.ClientColor = .none) -> TESerialMessage {
        userAction(.changeVolume, payload: Data([volume, color.rawValue]))
    }

    public static func switchSource(_ source: TESerial.Source) -> TESerialMessage {
        userAction(.switchSource, payload: Data([source.rawValue]))
    }

    public static func setDeviceName(_ name: String) -> TESerialMessage {
        let nameData = Data(name.prefix(16).utf8)
        return userAction(.setDeviceName, payload: nameData)
    }

    public static func setFmFrequency(_ frequency: UInt16) -> TESerialMessage {
        userAction(.setFmFrequency, payload: Data([UInt8(frequency >> 8), UInt8(frequency & 0xFF)]))
    }

    public static func setBtMode(_ mode: TESerial.BTMode) -> TESerialMessage {
        userAction(.setBtMode, payload: Data([mode.rawValue]))
    }

    public static func setParameter(_ param: TESerial.Parameter, value: UInt8) -> TESerialMessage {
        userAction(.setParameter, payload: Data([param.rawValue, value]))
    }

    public static func motorCalibration(_ motor: TESerial.Motor) -> TESerialMessage {
        userAction(.motorCalibrationRequest, payload: Data([motor.rawValue]))
    }

    public static func enableMotor(_ enable: Bool, motor: TESerial.Motor) -> TESerialMessage {
        userAction(.enableMotorRequest, payload: Data([enable ? TESerial.enable : TESerial.disable, motor.rawValue]))
    }

    public static func setBtAutoSwitch(_ enable: Bool) -> TESerialMessage {
        userAction(.setBtAutoSwitchRequest, payload: Data([enable ? TESerial.enable : TESerial.disable]))
    }

    public static func controlClickmix(_ enable: Bool) -> TESerialMessage {
        userAction(.controlClickmix, payload: Data([enable ? TESerial.enable : TESerial.disable]))
    }
}
