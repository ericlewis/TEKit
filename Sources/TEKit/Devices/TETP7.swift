import Foundation

/// TP-7 SysEx-based protocol for audio transfer and transport control
public enum TETP7Message: UInt8, Sendable {
    case sessionActive = 0x01
    case trackEvent = 0x02
    case playbackState = 0x03
    case recordingState = 0x04
    case positionEvent = 0x05
    case fileTransferActive = 0x06
    case audioData = 0x07
    case audioComplete = 0x08
    case requestAudio = 0x09
    case trackMissingOnDevice = 0x0A
}

public enum TETP7Event: Sendable {
    case sessionActive(Bool)
    case trackEvent(trackCount: Int)
    case playbackState(isPlaying: Bool)
    case recordingState(isRecording: Bool)
    case positionEvent(milliseconds: UInt32)
    case fileTransferActive(Bool)
    case audioData(offset: UInt32, data: Data)
    case audioComplete(reason: String)
    case trackMissing
}

@Observable
public final class TETP7: @unchecked Sendable {
    public let device: TEDevice

    public private(set) var isPlaying = false
    public private(set) var isRecording = false
    public private(set) var isSessionActive = false
    public private(set) var isTransferring = false
    public private(set) var positionMs: UInt32 = 0
    public private(set) var trackCount: Int = 0
    public private(set) var audioBuffer = Data()

    public init(device: TEDevice) {
        self.device = device
    }

    public func startListening() async {
        for await event in device.transport.events {
            if case .data(let data) = event {
                // TP-7 uses SysEx over BLE MIDI
                if let sysex = TESysExMessage.parse(data) {
                    handleSysEx(sysex)
                }
            }
        }
    }

    private func handleSysEx(_ msg: TESysExMessage) {
        guard msg.command == TESysEx.Command.productSpecific.rawValue else { return }
        // Product-specific command parsing would go here
        // The exact byte layout requires more reverse engineering
    }

    // MARK: - Commands

    public func sendGreeting() async throws {
        try await device.transport.send(TESysExMessage.greeting().encoded)
    }

    public func requestAudio(trackIndex: Int) async throws {
        audioBuffer = Data()
        isTransferring = true
        // Send REQUEST_AUDIO via SysEx
        let msg = TESysExMessage(
            command: TESysEx.Command.productSpecific.rawValue,
            productSpecificCommand: TETP7Message.requestAudio.rawValue,
            data: Data([UInt8(trackIndex)])
        )
        try await device.transport.send(msg.encoded)
    }

    public func requestBattery() async throws {
        try await device.transport.send(TESerialMessage.requestBattery().encoded)
    }

    public func requestMetadata() async throws {
        try await device.transport.send(TESerialMessage.requestMetadata().encoded)
    }
}
