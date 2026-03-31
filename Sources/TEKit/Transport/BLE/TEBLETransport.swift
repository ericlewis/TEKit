import Foundation
@preconcurrency import CoreBluetooth

public enum TEUUID {
    public static let teService = CBUUID(string: "10a6e10a-6e00-4de3-abba-dabbad000000")
    public static let teCharacteristic = CBUUID(string: "c1832aeb-6409-4b97-9575-208525a8213b")
    public static let teCharacteristicLegacy = CBUUID(string: "10a6e10a-6e00-4de3-abba-dabbadeeeeee")
    public static let midiService = CBUUID(string: "03b80e5a-ede8-4b33-a751-6ce34ec4c700")
    public static let midiCharacteristic = CBUUID(string: "7772e5db-3868-4112-a1a9-f2669d106bf3")

    // TP-7 custom
    public static let tp7Service = CBUUID(string: "A9E90000-194C-4523-A473-5FDF36AA4D20")
    public static let tp7Char1 = CBUUID(string: "A9E90001-194C-4523-A473-5FDF36AA4D20")
    public static let tp7Char2 = CBUUID(string: "A9E90002-194C-4523-A473-5FDF36AA4D20")

    public static let manufacturerDataPrefix: [UInt8] = [0x50, 0x04, 0x0B]
}

public final class TEBLETransport: NSObject, TETransport, @unchecked Sendable {
    public private(set) var state: TETransportState = .disconnected

    private let peripheral: CBPeripheral
    private let centralManager: CBCentralManager
    private var writeCharacteristic: CBCharacteristic?
    private var continuation: AsyncStream<TETransportEvent>.Continuation?
    private var connectContinuation: CheckedContinuation<Void, Error>?

    public lazy var events: AsyncStream<TETransportEvent> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    public init(peripheral: CBPeripheral, centralManager: CBCentralManager) {
        self.peripheral = peripheral
        self.centralManager = centralManager
        super.init()
        self.peripheral.delegate = self
    }

    public func connect() async throws {
        state = .connecting
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connectContinuation = cont
            centralManager.connect(peripheral, options: [
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
            ])
        }
    }

    public func disconnect() async {
        state = .disconnecting
        centralManager.cancelPeripheralConnection(peripheral)
        state = .disconnected
        continuation?.yield(.disconnected(nil))
    }

    public func send(_ data: Data) async throws {
        guard let char = writeCharacteristic else {
            throw TEBLEError.notConnected
        }
        peripheral.writeValue(data, for: char, type: .withoutResponse)
    }

    func didConnect() {
        state = .connected
        peripheral.discoverServices([TEUUID.teService, TEUUID.midiService, TEUUID.tp7Service])
    }

    func didFailToConnect(_ error: Error?) {
        state = .disconnected
        connectContinuation?.resume(throwing: error ?? TEBLEError.connectionFailed)
        connectContinuation = nil
    }

    func didDisconnect(_ error: Error?) {
        state = .disconnected
        continuation?.yield(.disconnected(error))
    }
}

extension TEBLETransport: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] {
            // Prefer new characteristic, fallback to legacy
            if char.uuid == TEUUID.teCharacteristic {
                writeCharacteristic = char
            } else if char.uuid == TEUUID.teCharacteristicLegacy && writeCharacteristic == nil {
                writeCharacteristic = char
            }

            // Subscribe to notifications
            if char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)
            }
        }

        // If we found a write characteristic, connection is complete
        if writeCharacteristic != nil {
            // Request maximum MTU
            peripheral.maximumWriteValueLength(for: .withoutResponse)
            continuation?.yield(.connected)
            connectContinuation?.resume()
            connectContinuation = nil
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        continuation?.yield(.data(data))
    }
}

public enum TEBLEError: Error, Sendable {
    case notConnected
    case connectionFailed
    case characteristicNotFound
}

// MARK: - BLE Scanner

public final class TEBLEScanner: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    private var centralManager: CBCentralManager!
    private let onDeviceFound: @Sendable (TEDevice) -> Void
    private var knownPeripherals: [UUID: CBPeripheral] = [:]

    public init(onDeviceFound: @escaping @Sendable (TEDevice) -> Void) {
        self.onDeviceFound = onDeviceFound
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    public func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: [TEUUID.teService, TEUUID.midiService], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    public func stopScanning() {
        centralManager.stopScan()
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard knownPeripherals[peripheral.identifier] == nil else { return }
        knownPeripherals[peripheral.identifier] = peripheral

        // Check manufacturer data for TE prefix
        var deviceType: TEDeviceType = .unknown
        if let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            let bytes = Array(mfgData)
            if bytes.count >= 3 &&
               bytes[0] == TEUUID.manufacturerDataPrefix[0] &&
               bytes[1] == TEUUID.manufacturerDataPrefix[1] &&
               bytes[2] == TEUUID.manufacturerDataPrefix[2] {
                // Variant byte determines device type
                if bytes.count > 3 {
                    deviceType = Self.deviceType(fromVariant: bytes[3])
                }
            }
        }

        // Check service UUIDs for TP-7
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            if serviceUUIDs.contains(TEUUID.tp7Service) {
                deviceType = .tp7
            }
        }

        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown TE Device"
        let transport = TEBLETransport(peripheral: peripheral, centralManager: central)

        let device = TEDevice(
            id: peripheral.identifier.uuidString,
            name: name,
            type: deviceType,
            transport: transport
        )
        onDeviceFound(device)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Find the transport for this peripheral and notify it
        // This is handled by the TEBLETransport's connect flow
        if let transport = findTransport(for: peripheral) {
            transport.didConnect()
        }
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let transport = findTransport(for: peripheral) {
            transport.didFailToConnect(error)
        }
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        knownPeripherals.removeValue(forKey: peripheral.identifier)
        if let transport = findTransport(for: peripheral) {
            transport.didDisconnect(error)
        }
    }

    private func findTransport(for peripheral: CBPeripheral) -> TEBLETransport? {
        nil // In real usage, device manager would track this
    }

    private static func deviceType(fromVariant variant: UInt8) -> TEDeviceType {
        // Variant bytes from BLE advertising - mapped from observation
        switch variant {
        case 0x01: return .ob4
        case 0x02: return .opz
        default: return .unknown
        }
    }
}
