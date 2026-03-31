import Foundation

public enum TEOD11Command {
    public static func globalJoin(majorVersion: Int = 1, minorVersion: Int = 0) -> Data {
        encode("global_join", params: [
            "protocol_major_version": majorVersion,
            "protocol_minor_version": minorVersion
        ])
    }

    public static func groupJoin(colorIndex: Int, name: String, realtimeData: Bool = true, uid: String? = nil) -> Data {
        var params: [String: Any] = [
            "color_index": colorIndex,
            "name": name,
            "realtime_data": realtimeData
        ]
        if let uid { params["uid"] = uid }
        return encode("group_join", params: params)
    }

    public static func groupLeave() -> Data { encode("group_leave") }
    public static func groupEnterStandby() -> Data { encode("group_enter_standby") }

    public static func groupSetVolume(_ vol: Int) -> Data {
        encode("group_set_volume", params: ["vol": vol])
    }

    public static func groupChangeVolume(_ amount: Int) -> Data {
        encode("group_change_volume", params: ["amount": amount])
    }

    public static func groupSetMaxVolume(_ value: Int) -> Data {
        encode("group_set_max_volume", params: ["value": value])
    }

    public static func groupSetEqBassBoost(_ enabled: Bool) -> Data {
        encode("group_set_eq_bass_boost", params: ["enabled": enabled])
    }

    public static func groupSetEqMidBoost(_ enabled: Bool) -> Data {
        encode("group_set_eq_mid_boost", params: ["enabled": enabled])
    }

    public static func groupSetEqTrebleBoost(_ enabled: Bool) -> Data {
        encode("group_set_eq_treble_boost", params: ["enabled": enabled])
    }

    public static func groupSetInputSource(_ source: String) -> Data {
        encode("group_set_input_source", params: ["source": source])
    }

    public static func groupSetName(groupId: String, groupName: String) -> Data {
        encode("group_set_name", params: ["group_id": groupId, "group_name": groupName])
    }

    public static func playbackStart() -> Data { encode("playback_start") }
    public static func playbackStop() -> Data { encode("playback_stop") }

    public static func trackGetPos() -> Data { encode("track_get_pos") }

    public static func trackSeek(time: Double) -> Data {
        encode("track_seek", params: ["time": time])
    }

    public static func trackSkipToNext() -> Data { encode("track_skip_to_next") }
    public static func trackSkipToPrev() -> Data { encode("track_skip_to_prev") }

    public static func trackSkipTo(trackIndex: Int, history: Bool = false) -> Data {
        encode("track_skip_to", params: ["track_index": trackIndex, "history": history])
    }

    public static func speakerPing(value: Int = 0) -> Data {
        encode("speaker_ping", params: ["value": value])
    }

    public static func speakerPlayTestSound(mac: String) -> Data {
        encode("speaker_play_test_sound", params: ["mac": mac])
    }

    public static func speakerSetChannel(channel: String, mac: String) -> Data {
        encode("speaker_set_channel", params: ["channel": channel, "mac": mac])
    }

    public static func speakerSetMuteState(mac: String, muted: Bool) -> Data {
        encode("speaker_set_mute_state", params: ["mac": mac, "muted": muted])
    }

    public static func speakerSoftwareUpdate(mac: String, revision: String) -> Data {
        encode("speaker_software_update", params: ["mac": mac, "revision": revision])
    }

    public static func speakerMoveToNewGroup(groupName: String, mac: String) -> Data {
        encode("speaker_move_to_new_group", params: ["group_name": groupName, "mac": mac])
    }

    public static func speakerMoveToExistingGroup(groupId: String, mac: String) -> Data {
        encode("speaker_move_to_existing_group", params: ["group_id": groupId, "mac": mac])
    }

    public static func factoryReset() -> Data { encode("factory_reset") }

    public static func connectWifiNetwork(ssid: String, password: String, staticIp: String? = nil) -> Data {
        var params: [String: Any] = ["ssid": ssid, "password": password]
        if let staticIp { params["static_ip"] = staticIp }
        return encode("connect_wifi_network", params: params)
    }

    public static func getWifiNetworks() -> Data { encode("get_wifi_networks") }

    public static func serviceLogin(serviceId: String, username: String, password: String) -> Data {
        encode("service_login", params: ["service_id": serviceId, "username": username, "password": password])
    }

    public static func serviceLogout(serviceId: String) -> Data {
        encode("service_logout", params: ["service_id": serviceId])
    }

    // MARK: - Encoding

    private static func encode(_ action: String, params: [String: Any] = [:]) -> Data {
        var message: [String: Any] = ["action": action]
        for (k, v) in params { message[k] = v }
        return (try? JSONSerialization.data(withJSONObject: message)) ?? Data()
    }
}

// MARK: - Response Parsing

public enum TEOD11Event: Sendable {
    case speakerAdded(TEOD11Speaker)
    case speakerLost(mac: String)
    case speakerStateChanged(TEOD11Speaker)
    case groupFound(id: String, name: String)
    case groupLost(id: String)
    case clientInfo(TEOD11Client)
    case trackChanged(TEOD11Track)
    case volumeChanged(Int)
    case softwareUpdate(Bool)
    case wifiNetworks([[String: TEOD11JSONValue]])
    case unknown(String, [String: TEOD11JSONValue])
}

public indirect enum TEOD11JSONValue: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: TEOD11JSONValue])
    case array([TEOD11JSONValue])
    case null

    init?(any value: Any) {
        switch value {
        case let value as String:
            self = .string(value)
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .int(value)
        case let value as Double:
            self = .double(value)
        case let value as [String: Any]:
            self = .object(value.compactMapValues(TEOD11JSONValue.init(any:)))
        case let value as [Any]:
            self = .array(value.compactMap(TEOD11JSONValue.init(any:)))
        case _ as NSNull:
            self = .null
        default:
            return nil
        }
    }
}

public struct TEOD11Speaker: Sendable {
    public let mac: String
    public let name: String
    public let revision: String
    public let ip: String
    public let groupId: String
    public let channel: String
    public let muted: Bool

    public init(from dict: [String: Any]) {
        mac = dict["mac"] as? String ?? ""
        name = dict["name"] as? String ?? ""
        revision = dict["revision"] as? String ?? ""
        ip = dict["ip"] as? String ?? ""
        groupId = dict["group_id"] as? String ?? ""
        channel = dict["channel"] as? String ?? ""
        muted = dict["muted"] as? Bool ?? false
    }
}

public struct TEOD11Track: Sendable {
    public let artist: String
    public let track: String
    public let album: String
    public let trackIndex: Int

    public init(from dict: [String: Any]) {
        artist = dict["artist"] as? String ?? ""
        track = dict["track"] as? String ?? ""
        album = dict["album"] as? String ?? ""
        trackIndex = dict["track_index"] as? Int ?? 0
    }
}

public struct TEOD11Client: Sendable {
    public let sid: String
    public let uid: String
    public let name: String
    public let colorIndex: Int

    public init(from dict: [String: Any]) {
        sid = dict["sid"] as? String ?? ""
        uid = dict["uid"] as? String ?? ""
        name = dict["name"] as? String ?? ""
        colorIndex = dict["color_index"] as? Int ?? 0
    }
}

public struct TEOD11ResponseParser: Sendable {
    public init() {}

    public func parse(_ data: Data) -> TEOD11Event? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let update = json["update"] as? String else { return nil }

        switch update {
        case "speaker_added":
            if let speaker = json["speaker"] as? [String: Any] {
                return .speakerAdded(TEOD11Speaker(from: speaker))
            }
        case "speaker_lost":
            if let mac = json["mac"] as? String {
                return .speakerLost(mac: mac)
            }
        case "speaker_state_changed":
            if let speaker = json["speaker"] as? [String: Any] {
                return .speakerStateChanged(TEOD11Speaker(from: speaker))
            }
        case "group_found", "group_updated":
            if let id = json["id"] as? String, let name = json["name"] as? String {
                return .groupFound(id: id, name: name)
            }
        case "group_lost":
            if let id = json["id"] as? String {
                return .groupLost(id: id)
            }
        case "client_info":
            if let client = json["client"] as? [String: Any] {
                return .clientInfo(TEOD11Client(from: client))
            }
        case "track_changed":
            if let track = json["track"] as? [String: Any] {
                return .trackChanged(TEOD11Track(from: track))
            }
        case "volume_changed":
            if let vol = json["vol"] as? Int {
                return .volumeChanged(vol)
            }
        case "speaker_software_update":
            return .softwareUpdate(json["status"] as? Bool ?? false)
        case "wifi_networks":
            if let networks = json["wifi_networks"] as? [[String: Any]] ?? json["networks"] as? [[String: Any]] {
                return .wifiNetworks(networks.map { $0.compactMapValues(TEOD11JSONValue.init(any:)) })
            }
        default:
            return .unknown(update, json.compactMapValues(TEOD11JSONValue.init(any:)))
        }
        return nil
    }
}
