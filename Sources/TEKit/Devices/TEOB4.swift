import Foundation

@Observable
public final class TEOB4: @unchecked Sendable {
    public let device: TEDevice
    private let parser = TESerialParser()

    public private(set) var isPlaying = false
    public private(set) var volume: UInt8 = 0
    public private(set) var source: TESerial.SourceEvent?
    public private(set) var diskMode: TESerial.DiskMode?
    public private(set) var currentTrack: TrackInfo?
    public private(set) var playbackPosition: UInt16 = 0
    public private(set) var fmFrequency: UInt16 = 0
    public private(set) var fmRdsName: String = ""
    public private(set) var btMode: TESerial.BTMode = .simple
    public private(set) var deviceName: String = ""
    public private(set) var ambientWetness: UInt8 = 0
    public private(set) var ambientPrimary: UInt8 = 0

    public struct TrackInfo: Sendable {
        public let artist: String
        public let track: String
        public let album: String
        public let lengthSeconds: UInt16
    }

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
        case .playbackStatus(let status):
            isPlaying = status == .playing
        case .volumeChanged(let vol, _):
            volume = vol
        case .sourceChanged(let src, let mode):
            source = src
            diskMode = mode
        case .trackChanged(let artist, let track, let album, let length):
            currentTrack = TrackInfo(artist: artist, track: track, album: album, lengthSeconds: length)
        case .playbackPosition(let pos):
            playbackPosition = pos
        case .fmStation(let freq, let rds):
            fmFrequency = freq
            fmRdsName = rds
        case .btModeReply(let mode):
            btMode = mode
        case .deviceNameUpdated(let name):
            deviceName = name
        case .parameterUpdated(let param, let value):
            switch param {
            case .ambientWetness: ambientWetness = value
            case .ambientPrimary: ambientPrimary = value
            }
        case .batteryLevel(let level, let charging, let pluggedIn):
            device.updateBattery(TEBatteryState(level: Int(level), isCharging: charging, isPluggedIn: pluggedIn))
        case .metadata(let meta):
            device.updateMetadata(TEDeviceMetadata(raw: meta))
        default:
            break
        }
    }

    // MARK: - Commands

    private func send(_ msg: TESerialMessage) async throws {
        try await device.transport.send(msg.encoded)
    }

    public func play() async throws { try await send(.play()) }
    public func pause() async throws { try await send(.pause()) }
    public func togglePause() async throws { try await send(.togglePause()) }
    public func nextTrack() async throws { try await send(.nextTrack()) }
    public func prevTrack() async throws { try await send(.prevTrack()) }
    public func knockKnock() async throws { try await send(.knockKnock()) }

    public func setVolume(_ volume: UInt8, color: TESerial.ClientColor = .none) async throws {
        try await send(.changeVolume(volume, color: color))
    }

    public func switchSource(_ source: TESerial.Source) async throws {
        try await send(.switchSource(source))
    }

    public func setDeviceName(_ name: String) async throws {
        try await send(.setDeviceName(name))
    }

    public func setFmFrequency(_ frequency: UInt16) async throws {
        try await send(.setFmFrequency(frequency))
    }

    public func setBtMode(_ mode: TESerial.BTMode) async throws {
        try await send(.setBtMode(mode))
    }

    public func setAmbientWetness(_ value: UInt8) async throws {
        try await send(.setParameter(.ambientWetness, value: value))
    }

    public func setAmbientPrimary(_ value: UInt8) async throws {
        try await send(.setParameter(.ambientPrimary, value: value))
    }

    public func calibrateMotor(_ motor: TESerial.Motor) async throws {
        try await send(.motorCalibration(motor))
    }

    public func enableMotor(_ enable: Bool, motor: TESerial.Motor) async throws {
        try await send(.enableMotor(enable, motor: motor))
    }

    public func requestBattery() async throws {
        try await send(.requestBattery())
    }

    public func requestMetadata() async throws {
        try await send(.requestMetadata())
    }

    public func requestState() async throws {
        try await send(.connected())
    }
}
