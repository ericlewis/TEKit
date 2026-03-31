#if canImport(IOKit) && canImport(CoreMIDI)
import Foundation
import CoreMIDI

/// USB MIDI transport for macOS — communicates with TE devices via CoreMIDI SysEx
public final class TEUSBTransport: NSObject, TETransport, @unchecked Sendable {
    public private(set) var state: TETransportState = .disconnected

    private var midiClient: MIDIClientRef = 0
    private var midiOutputPort: MIDIPortRef = 0
    private var midiInputPort: MIDIPortRef = 0
    private var midiDestination: MIDIEndpointRef = 0
    private var midiSource: MIDIEndpointRef = 0
    private var continuation: AsyncStream<TETransportEvent>.Continuation?

    public let deviceName: String

    public lazy var events: AsyncStream<TETransportEvent> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    public init(deviceName: String) {
        self.deviceName = deviceName
        super.init()
    }

    public func connect() async throws {
        var status = MIDIClientCreateWithBlock("TEKit" as CFString, &midiClient) { [weak self] notification in
            // Handle MIDI setup changes
            let messageID = notification.pointee.messageID
            if messageID == .msgObjectRemoved {
                self?.state = .disconnected
                self?.continuation?.yield(.disconnected(nil))
            }
        }
        guard status == noErr else { throw TEUSBError.midiClientCreationFailed }

        status = MIDIOutputPortCreate(midiClient, "TEKit Output" as CFString, &midiOutputPort)
        guard status == noErr else { throw TEUSBError.midiPortCreationFailed }

        // Find TE device endpoint
        let destCount = MIDIGetNumberOfDestinations()
        for i in 0..<destCount {
            let endpoint = MIDIGetDestination(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
            if let n = name?.takeRetainedValue() as String?,
               n.lowercased().contains("teenage") || n.lowercased().contains(deviceName.lowercased()) {
                midiDestination = endpoint
                break
            }
        }

        guard midiDestination != 0 else { throw TEUSBError.deviceNotFound }

        // Set up input
        let srcCount = MIDIGetNumberOfSources()
        for i in 0..<srcCount {
            let endpoint = MIDIGetSource(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
            if let n = name?.takeRetainedValue() as String?,
               n.lowercased().contains("teenage") || n.lowercased().contains(deviceName.lowercased()) {
                midiSource = endpoint
                break
            }
        }

        if midiSource != 0 {
            status = MIDIInputPortCreateWithProtocol(
                midiClient,
                "TEKit Input" as CFString,
                ._1_0,
                &midiInputPort
            ) { [weak self] eventList, _ in
                self?.handleMIDIInput(eventList)
            }

            if status == noErr {
                MIDIPortConnectSource(midiInputPort, midiSource, nil)
            }
        }

        state = .connected
        continuation?.yield(.connected)
    }

    public func disconnect() async {
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
            midiClient = 0
        }
        state = .disconnected
        continuation?.yield(.disconnected(nil))
    }

    public func send(_ data: Data) async throws {
        guard midiDestination != 0 else { throw TEUSBError.deviceNotFound }

        // Send as SysEx
        let bytes = Array(data)

        try bytes.withUnsafeBufferPointer { buffer in
            var request = MIDISysexSendRequest(
                destination: midiDestination,
                data: buffer.baseAddress!,
                bytesToSend: UInt32(bytes.count),
                complete: false,
                reserved: (0, 0, 0),
                completionProc: { _ in },
                completionRefCon: nil
            )

            let status = MIDISendSysex(&request)
            guard status == noErr else { throw TEUSBError.sendFailed }
        }
    }

    private func handleMIDIInput(_ eventList: UnsafePointer<MIDIEventList>) {
        let list = eventList.pointee
        withUnsafePointer(to: list.packet) { ptr in
            var packet: UnsafePointer<MIDIEventPacket> = ptr
            for _ in 0..<list.numPackets {
                let p = packet.pointee
                let wordCount = Int(p.wordCount)
                if wordCount > 0 {
                    withUnsafeBytes(of: p.words) { rawBuffer in
                        let data = Data(rawBuffer.prefix(wordCount * 4))
                        continuation?.yield(.data(data))
                    }
                }
                packet = UnsafePointer(MIDIEventPacketNext(packet))
            }
        }
    }
}

public enum TEUSBError: Error, Sendable {
    case midiClientCreationFailed
    case midiPortCreationFailed
    case deviceNotFound
    case sendFailed
}
#endif
