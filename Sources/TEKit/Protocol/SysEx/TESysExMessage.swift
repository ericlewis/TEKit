import Foundation

public enum TESysEx {
    // TE Manufacturer ID (European: 00 20 76)
    public static let manufacturerID: [UInt8] = [0x00, 0x20, 0x76]

    public enum Command: UInt8, Sendable {
        case greeting = 0x01
        case productSpecific = 0x02
    }

    public enum ResponseStatus: UInt8, Sendable {
        case ok = 0x00
        case error = 0x01
    }
}

public struct TESysExMessage: Sendable {
    public let command: UInt8
    public let productSpecificCommand: UInt8
    public let isResponse: Bool
    public let responseStatus: TESysEx.ResponseStatus
    public let data: Data
    public let requestId: UInt8?

    public init(command: UInt8, productSpecificCommand: UInt8 = 0,
                isResponse: Bool = false, responseStatus: TESysEx.ResponseStatus = .ok,
                data: Data = Data(), requestId: UInt8? = nil) {
        self.command = command
        self.productSpecificCommand = productSpecificCommand
        self.isResponse = isResponse
        self.responseStatus = responseStatus
        self.data = data
        self.requestId = requestId
    }

    public var encoded: Data {
        var bytes: [UInt8] = [0xF0] // SysEx start
        bytes.append(contentsOf: TESysEx.manufacturerID)
        bytes.append(command)
        if command == TESysEx.Command.productSpecific.rawValue {
            bytes.append(productSpecificCommand)
        }
        bytes.append(contentsOf: data)
        bytes.append(0xF7) // SysEx end
        return Data(bytes)
    }

    public static func greeting() -> TESysExMessage {
        TESysExMessage(command: TESysEx.Command.greeting.rawValue)
    }

    public static func parse(_ data: Data) -> TESysExMessage? {
        let bytes = Array(data)
        guard bytes.count >= 5,
              bytes[0] == 0xF0,
              bytes.last == 0xF7 else { return nil }

        // Verify manufacturer ID
        guard bytes[1] == TESysEx.manufacturerID[0],
              bytes[2] == TESysEx.manufacturerID[1],
              bytes[3] == TESysEx.manufacturerID[2] else { return nil }

        let command = bytes[4]
        let payload = Data(bytes[5..<(bytes.count - 1)])

        return TESysExMessage(
            command: command,
            data: payload
        )
    }
}
