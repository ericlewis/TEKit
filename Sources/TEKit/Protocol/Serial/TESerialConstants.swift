import Foundation

// Extracted from orthoplay.js SERIAL_DEFINES_ORTHOPLAY (lines 11947-12180)

public enum TESerial {

    // MARK: - Routing IDs

    public static let orthoplay: UInt8 = 0x06
    public static let app: UInt8 = 0x01
    public static let ble: UInt8 = 0x03

    public static let appToOrthoplay: UInt8 = 0x16
    public static let bleToOrthoplay: UInt8 = 0x36
    public static let orthoplayToApp: UInt8 = 0x61
    public static let orthoplayToBle: UInt8 = 0x63

    // MARK: - Client Colors

    public enum ClientColor: UInt8, Sendable, CaseIterable {
        case blue = 0x00
        case green = 0x01
        case orange = 0x02
        case red = 0x03
        case black = 0x04
        case grey = 0x05
        case yellow = 0x06
        case white = 0x07
        case none = 0xFF
    }

    // MARK: - Common Messages

    public enum Message: UInt8, Sendable {
        case ping = 0x01
        case pong = 0x02
        case log = 0x03
        case error = 0x04
        case readMetadataRequest = 0x09
        case readMetadataReply = 0x0A
        case dfuRequest = 0x0D
        case dfuReply = 0x0E
        case common = 0x0F
        case userAction = 0x58
        case userEvent = 0x59
        case batteryLevelRequest = 0x5E
        case batteryLevelReply = 0x5F
        case audioDevicesRequest = 0x75
        case audioDevicesReply = 0x76
        case blePeerUniqueIdRequest = 0x96
        case blePeerUniqueIdReply = 0x97
    }

    // MARK: - User Actions (App → Device)

    public enum UserAction: UInt8, Sendable {
        case play = 0x01
        case pause = 0x02
        case togglePause = 0x03
        case prevTrack = 0x04
        case nextTrack = 0x05
        case changeVolume = 0x06
        case connected = 0x07
        case switchSource = 0x08
        case motorCalibrationRequest = 0x09
        case knockKnock = 0x0A
        case setDeviceName = 0x0B
        case enableMotorRequest = 0x0C
        case setBtAutoSwitchRequest = 0x0D
        case setParameter = 0x0E
        case controlClickmix = 0x0F
        case setFmFrequency = 0x10
        case setBtMode = 0x11
    }

    // MARK: - Input Sources

    public enum Source: UInt8, Sendable {
        case lineIn = 0xF0
        case bluetooth = 0xF1
        case fm = 0xF2
        case disk = 0xF3
    }

    // MARK: - Disk Modes

    public enum DiskMode: UInt8, Sendable {
        case karma = 0xF3
        case ambient = 0xF4
        case metronome = 0xF5
        case noise = 0xF6
        case loop = 0xF7
    }

    // MARK: - Motors

    public enum Motor: UInt8, Sendable {
        case volume = 0xF4
        case scrub = 0xF5
    }

    // MARK: - BT Modes

    public enum BTMode: UInt8, Sendable {
        case simple = 0x99
        case party = 0x19
    }

    // MARK: - Parameters

    public enum Parameter: UInt8, Sendable {
        case ambientWetness = 0x01
        case ambientPrimary = 0x02
    }

    // MARK: - User Events (Device → App)

    public enum UserEvent: UInt8, Sendable {
        case playbackStatus = 0x01
        case sourceChanged = 0x04
        case trackChanged = 0x0A
        case volumeChanged = 0x0B
        case mtuUpdated = 0x0C
        case fmStation = 0x0D
        case playbackPosition = 0x0E
        case motorCalibrationReply = 0x09
        case deviceNameUpdated = 0x0F
        case btAutoSwitchReply = 0x10
        case parameterUpdated = 0x11
        case btModeReply = 0x12
    }

    public enum PlaybackStatus: UInt8, Sendable {
        case playing = 0x02
        case paused = 0x03
    }

    public enum SourceEvent: UInt8, Sendable {
        case lineIn = 0x05
        case bluetooth = 0x06
        case fm = 0x07
        case disk = 0x08
        case ble = 0x09
    }

    // MARK: - Battery

    public static let batteryAcIn: UInt8 = 0x80
    public static let batteryIsCharging: UInt8 = 0x40

    // MARK: - DFU

    public enum DFURequest: UInt8, Sendable {
        case enterDFU = 0xEE
        case exitDFU = 0x18
        case prepareRegular = 0x02
        case prepareCompressed = 0xAA
        case prepareSigned = 0xAB
        case partApp = 0xB0
        case partBootloader = 0xB1
        case chunk = 0x03
        case perform = 0x05
        case mode = 0x10
    }

    public enum DFUReply: UInt8, Sendable {
        case ok = 0x54
        case progress = 0x92
        case fail = 0x84
    }

    public enum DFUMode: UInt8, Sendable {
        case disk = 0x01
        case cdc = 0x02
        case midi = 0x03
        case ble = 0x04
        case invalidApp = 0x05
    }

    // MARK: - Audio Devices

    public enum AudioDevicesRequest: UInt8, Sendable {
        case list = 0x03
        case unpair = 0x04
    }

    public enum AudioDevicesReply: UInt8, Sendable {
        case pairedDevice = 0x5E
        case connected = 0x6A
        case notConnected = 0x6B
        case deviceUnpaired = 0x5F
        case error = 0x77
    }

    // MARK: - Enable/Disable

    public static let enable: UInt8 = 0x03
    public static let disable: UInt8 = 0x18
}
