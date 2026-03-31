import Foundation

@Observable
public final class TEDeviceManager: @unchecked Sendable {
    public private(set) var discoveredDevices: [TEDevice] = []
    public private(set) var isScanning = false

    private var bleScanner: TEBLEScanner?
    private var bonjourBrowser: TEBonjourBrowser?

    public init() {}

    public func startScanning() {
        isScanning = true
        bleScanner = TEBLEScanner { [weak self] device in
            self?.addDevice(device)
        }
        bleScanner?.startScanning()

        bonjourBrowser = TEBonjourBrowser { [weak self] device in
            self?.addDevice(device)
        }
        bonjourBrowser?.startBrowsing()
    }

    public func stopScanning() {
        isScanning = false
        bleScanner?.stopScanning()
        bonjourBrowser?.stopBrowsing()
    }

    private func addDevice(_ device: TEDevice) {
        if !discoveredDevices.contains(where: { $0.id == device.id }) {
            discoveredDevices.append(device)
        }
    }

    public func removeDevice(_ device: TEDevice) {
        discoveredDevices.removeAll { $0.id == device.id }
    }
}
