import Foundation

@Observable
public final class TEOD11: @unchecked Sendable {
    public let device: TEDevice
    private let responseParser = TEOD11ResponseParser()

    public private(set) var speakers: [TEOD11Speaker] = []
    public private(set) var currentTrack: TEOD11Track?
    public private(set) var volume: Int = 0
    public private(set) var groupName: String = ""
    public private(set) var groupId: String = ""

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
        guard let event = responseParser.parse(data) else { return }
        switch event {
        case .speakerAdded(let speaker):
            if !speakers.contains(where: { $0.mac == speaker.mac }) {
                speakers.append(speaker)
            }
        case .speakerLost(let mac):
            speakers.removeAll { $0.mac == mac }
        case .speakerStateChanged(let speaker):
            if let idx = speakers.firstIndex(where: { $0.mac == speaker.mac }) {
                speakers[idx] = speaker
            }
        case .groupFound(let id, let name):
            groupId = id
            groupName = name
        case .trackChanged(let track):
            currentTrack = track
        case .volumeChanged(let vol):
            volume = vol
        default:
            break
        }
    }

    private var wsTransport: TEWebSocketTransport? {
        device.transport as? TEWebSocketTransport
    }

    // MARK: - Commands

    public func join(name: String = "TEKit", colorIndex: Int = 0) async throws {
        try await wsTransport?.sendJSON("global_join", params: [
            "protocol_major_version": 1, "protocol_minor_version": 0
        ])
        try await wsTransport?.sendJSON("group_join", params: [
            "color_index": colorIndex, "name": name, "realtime_data": true
        ])
    }

    public func leave() async throws {
        try await wsTransport?.sendJSON("group_leave")
    }

    public func playbackStart() async throws {
        try await wsTransport?.sendJSON("playback_start")
    }

    public func playbackStop() async throws {
        try await wsTransport?.sendJSON("playback_stop")
    }

    public func setVolume(_ vol: Int) async throws {
        try await wsTransport?.sendJSON("group_set_volume", params: ["vol": vol])
    }

    public func changeVolume(_ amount: Int) async throws {
        try await wsTransport?.sendJSON("group_change_volume", params: ["amount": amount])
    }

    public func nextTrack() async throws {
        try await wsTransport?.sendJSON("track_skip_to_next")
    }

    public func prevTrack() async throws {
        try await wsTransport?.sendJSON("track_skip_to_prev")
    }

    public func seek(time: Double) async throws {
        try await wsTransport?.sendJSON("track_seek", params: ["time": time])
    }

    public func setBassBoost(_ enabled: Bool) async throws {
        try await wsTransport?.sendJSON("group_set_eq_bass_boost", params: ["enabled": enabled])
    }

    public func setTrebleBoost(_ enabled: Bool) async throws {
        try await wsTransport?.sendJSON("group_set_eq_treble_boost", params: ["enabled": enabled])
    }

    public func setInputSource(_ source: String) async throws {
        try await wsTransport?.sendJSON("group_set_input_source", params: ["source": source])
    }

    public func enterStandby() async throws {
        try await wsTransport?.sendJSON("group_enter_standby")
    }

    public func factoryReset() async throws {
        try await wsTransport?.sendJSON("factory_reset")
    }

    public func ping() async throws {
        try await wsTransport?.sendJSON("speaker_ping", params: ["value": 0])
    }
}
