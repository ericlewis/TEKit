import Foundation

public enum TESerialEvent: Sendable {
    case playbackStatus(TESerial.PlaybackStatus)
    case sourceChanged(TESerial.SourceEvent, diskMode: TESerial.DiskMode?)
    case trackChanged(artist: String, track: String, album: String, lengthSeconds: UInt16)
    case volumeChanged(volume: UInt8, color: TESerial.ClientColor)
    case mtuUpdated(UInt16)
    case fmStation(frequency: UInt16, rdsName: String)
    case playbackPosition(seconds: UInt16)
    case deviceNameUpdated(String)
    case btModeReply(TESerial.BTMode)
    case parameterUpdated(TESerial.Parameter, value: UInt8)
    case batteryLevel(level: UInt8, isCharging: Bool, isPluggedIn: Bool)
    case metadata([String: String])
    case pong(Data)
    case log(String)
    case error(String)
    case dfuReply(TESerial.DFUReply, message: String)
    case unknown(TESerialMessage)
}

public struct TESerialParser: Sendable {

    public init() {}

    public func parse(_ data: Data) -> TESerialEvent? {
        guard data.count >= 2 else { return nil }
        let routing = data[data.startIndex]
        let command = data[data.startIndex + 1]
        let payload = data.dropFirst(2)

        guard let msg = TESerial.Message(rawValue: command) else {
            return .unknown(TESerialMessage(routing: routing, command: command, payload: Data(payload)))
        }

        switch msg {
        case .pong:
            return .pong(Data(payload))

        case .log:
            return .log(parseLogMessage(payload))

        case .error:
            return .error(parseLogMessage(payload))

        case .readMetadataReply:
            return .metadata(parseMetadata(payload))

        case .batteryLevelReply:
            guard payload.count >= 2 else { return nil }
            let level = payload[payload.startIndex]
            let state = payload[payload.startIndex + 1]
            return .batteryLevel(
                level: level,
                isCharging: state & TESerial.batteryIsCharging != 0,
                isPluggedIn: state & TESerial.batteryAcIn != 0
            )

        case .userEvent:
            return parseUserEvent(payload)

        case .dfuReply:
            guard payload.count >= 1,
                  let status = TESerial.DFUReply(rawValue: payload[payload.startIndex]) else { return nil }
            let message = payload.count > 1 ? String(data: Data(payload.dropFirst()), encoding: .utf8) ?? "" : ""
            return .dfuReply(status, message: message)

        default:
            return .unknown(TESerialMessage(routing: routing, command: command, payload: Data(payload)))
        }
    }

    private func parseUserEvent(_ payload: Data) -> TESerialEvent? {
        guard let first = payload.first,
              let event = TESerial.UserEvent(rawValue: first) else { return nil }
        let rest = payload.dropFirst()

        switch event {
        case .playbackStatus:
            guard let statusByte = rest.first,
                  let status = TESerial.PlaybackStatus(rawValue: statusByte) else { return nil }
            return .playbackStatus(status)

        case .sourceChanged:
            guard let sourceByte = rest.first,
                  let source = TESerial.SourceEvent(rawValue: sourceByte) else { return nil }
            var diskMode: TESerial.DiskMode?
            if source == .disk, rest.count > 1 {
                diskMode = TESerial.DiskMode(rawValue: rest[rest.startIndex + 1])
            }
            return .sourceChanged(source, diskMode: diskMode)

        case .trackChanged:
            return parseTrackChanged(rest)

        case .volumeChanged:
            guard rest.count >= 2 else { return nil }
            let color = TESerial.ClientColor(rawValue: rest[rest.startIndex + 1]) ?? .none
            return .volumeChanged(volume: rest[rest.startIndex], color: color)

        case .mtuUpdated:
            guard rest.count >= 2 else { return nil }
            let mtu = UInt16(rest[rest.startIndex]) << 8 | UInt16(rest[rest.startIndex + 1])
            return .mtuUpdated(mtu)

        case .fmStation:
            guard rest.count >= 2 else { return nil }
            let freq = UInt16(rest[rest.startIndex]) << 8 | UInt16(rest[rest.startIndex + 1])
            let name = rest.count > 2 ? String(data: Data(rest.dropFirst(2)), encoding: .utf8) ?? "" : ""
            return .fmStation(frequency: freq, rdsName: name)

        case .playbackPosition:
            guard rest.count >= 2 else { return nil }
            let pos = UInt16(rest[rest.startIndex]) << 8 | UInt16(rest[rest.startIndex + 1])
            return .playbackPosition(seconds: pos)

        case .deviceNameUpdated:
            let name = String(data: Data(rest), encoding: .utf8) ?? ""
            return .deviceNameUpdated(name)

        case .btModeReply:
            guard let modeByte = rest.first,
                  let mode = TESerial.BTMode(rawValue: modeByte) else { return nil }
            return .btModeReply(mode)

        case .parameterUpdated:
            guard rest.count >= 2,
                  let param = TESerial.Parameter(rawValue: rest[rest.startIndex]) else { return nil }
            return .parameterUpdated(param, value: rest[rest.startIndex + 1])

        default:
            return nil
        }
    }

    private func parseTrackChanged(_ data: Data) -> TESerialEvent? {
        let bytes = Array(data)
        let parts = bytes.split(separator: 0x00, maxSplits: 3, omittingEmptySubsequences: false)
        let artist = parts.count > 0 ? String(bytes: parts[0], encoding: .utf8) ?? "" : ""
        let track = parts.count > 1 ? String(bytes: parts[1], encoding: .utf8) ?? "" : ""
        let album = parts.count > 2 ? String(bytes: parts[2], encoding: .utf8) ?? "" : ""
        var length: UInt16 = 0
        if parts.count > 3 && parts[3].count >= 2 {
            length = UInt16(parts[3][0]) << 8 | UInt16(parts[3][1])
        }
        return .trackChanged(artist: artist, track: track, album: album, lengthSeconds: length)
    }

    private func parseMetadata(_ data: Data) -> [String: String] {
        guard let str = String(data: Data(data), encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for pair in str.split(separator: ";") {
            let kv = pair.split(separator: ":", maxSplits: 1)
            if kv.count == 2 {
                result[String(kv[0])] = String(kv[1])
            }
        }
        return result
    }

    private func parseLogMessage(_ data: Data) -> String {
        // First 4 bytes are timestamp, rest is ASCII
        guard data.count > 4 else { return String(data: Data(data), encoding: .utf8) ?? "" }
        return String(data: Data(data.dropFirst(4)), encoding: .utf8) ?? ""
    }
}
