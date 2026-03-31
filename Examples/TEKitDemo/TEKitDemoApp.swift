import SwiftUI
import TEKit

@main
struct TEKitDemoApp: App {
    @State private var deviceManager = TEDeviceManager()

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                DeviceListView(deviceManager: deviceManager)
            } detail: {
                Text("Select a device")
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                deviceManager.startScanning()
            }
        }
    }
}

struct DeviceListView: View {
    let deviceManager: TEDeviceManager

    var body: some View {
        List(deviceManager.discoveredDevices) { device in
            NavigationLink(value: device.id) {
                DeviceRow(device: device)
            }
        }
        .navigationTitle("TE Devices")
        .overlay {
            if deviceManager.discoveredDevices.isEmpty {
                ContentUnavailableView {
                    Label("Scanning...", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Looking for Teenage Engineering devices")
                }
            }
        }
        .navigationDestination(for: String.self) { id in
            if let device = deviceManager.discoveredDevices.first(where: { $0.id == id }) {
                DeviceDetailView(device: device)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    if deviceManager.isScanning {
                        deviceManager.stopScanning()
                    } else {
                        deviceManager.startScanning()
                    }
                } label: {
                    Image(systemName: deviceManager.isScanning ? "stop.circle" : "arrow.clockwise")
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: TEDevice

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                Text(device.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
    }

    var iconName: String {
        switch device.type {
        case .ob4: "hifispeaker"
        case .od11: "hifispeaker.2"
        case .opz: "pianokeys"
        case .tp7: "recordingtape"
        case .ep133, .koII: "dial.medium"
        case .unknown: "questionmark.circle"
        }
    }

    var statusColor: Color {
        switch device.connectionState {
        case .connected: .green
        case .connecting, .disconnecting: .orange
        case .disconnected: .gray
        }
    }
}

struct DeviceDetailView: View {
    let device: TEDevice
    @State private var ob4: TEOB4?
    @State private var od11: TEOD11?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection
                GroupBox("Connection") {
                    HStack {
                        Text(device.connectionState == .connected ? "Connected" : "Disconnected")
                        Spacer()
                        Button(device.connectionState == .connected ? "Disconnect" : "Connect") {
                            Task {
                                if device.connectionState == .connected {
                                    await device.disconnect()
                                } else {
                                    try? await device.connect()
                                    setupDevice()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                // Device info
                if let meta = device.metadata {
                    GroupBox("Info") {
                        LabeledContent("Product", value: meta.product ?? "–")
                        LabeledContent("Serial", value: meta.serialNumber ?? "–")
                        LabeledContent("Firmware", value: meta.softwareVersion ?? "–")
                    }
                }

                // Battery
                if let battery = device.battery {
                    GroupBox("Battery") {
                        HStack {
                            Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.75")
                            Text("\(battery.level)%")
                            if battery.isPluggedIn {
                                Image(systemName: "powerplug")
                            }
                        }
                    }
                }

                // OB-4 controls
                if let ob4 {
                    OB4ControlsView(ob4: ob4)
                }

                // OD-11 controls
                if let od11 {
                    OD11ControlsView(od11: od11)
                }
            }
            .padding()
        }
        .navigationTitle(device.name)
    }

    func setupDevice() {
        switch device.type {
        case .ob4:
            let controller = TEOB4(device: device)
            ob4 = controller
            Task {
                try? await controller.requestState()
                try? await controller.requestMetadata()
                try? await controller.requestBattery()
                await controller.startListening()
            }
        case .od11:
            let controller = TEOD11(device: device)
            od11 = controller
            Task {
                try? await controller.join()
                await controller.startListening()
            }
        default:
            break
        }
    }
}

struct OB4ControlsView: View {
    let ob4: TEOB4

    var body: some View {
        GroupBox("Transport") {
            HStack(spacing: 16) {
                Button { Task { try? await ob4.prevTrack() } } label: {
                    Image(systemName: "backward.fill")
                }
                Button { Task { try? await ob4.togglePause() } } label: {
                    Image(systemName: ob4.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                Button { Task { try? await ob4.nextTrack() } } label: {
                    Image(systemName: "forward.fill")
                }
            }
            .font(.title2)

            if let track = ob4.currentTrack {
                VStack {
                    Text(track.track).font(.headline)
                    Text(track.artist).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }

        GroupBox("Volume") {
            HStack {
                Image(systemName: "speaker")
                Slider(value: Binding(
                    get: { Double(ob4.volume) },
                    set: { Task { try? await ob4.setVolume(UInt8($0)) } }
                ), in: 0...100)
                Image(systemName: "speaker.wave.3")
                Text("\(ob4.volume)")
                    .monospacedDigit()
                    .frame(width: 30)
            }
        }

        GroupBox("Source") {
            HStack(spacing: 12) {
                ForEach([(TESerial.Source.bluetooth, "dot.radiowaves.right"),
                         (.lineIn, "cable.connector"),
                         (.fm, "radio"),
                         (.disk, "opticaldisc")], id: \.0.rawValue) { source, icon in
                    Button { Task { try? await ob4.switchSource(source) } } label: {
                        Label(String(describing: source), systemImage: icon)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }

        GroupBox("Fun") {
            Button { Task { try? await ob4.knockKnock() } } label: {
                Label("Knock Knock", systemImage: "hand.tap")
            }
        }
    }
}

struct OD11ControlsView: View {
    let od11: TEOD11

    var body: some View {
        GroupBox("Playback") {
            HStack(spacing: 16) {
                Button { Task { try? await od11.prevTrack() } } label: {
                    Image(systemName: "backward.fill")
                }
                Button { Task { try? await od11.playbackStart() } } label: {
                    Image(systemName: "play.fill").font(.title)
                }
                Button { Task { try? await od11.playbackStop() } } label: {
                    Image(systemName: "stop.fill").font(.title)
                }
                Button { Task { try? await od11.nextTrack() } } label: {
                    Image(systemName: "forward.fill")
                }
            }
            .font(.title2)

            if let track = od11.currentTrack {
                VStack {
                    Text(track.track).font(.headline)
                    Text(track.artist).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }

        GroupBox("Volume") {
            HStack {
                Button { Task { try? await od11.changeVolume(-5) } } label: {
                    Image(systemName: "speaker.minus")
                }
                Text("\(od11.volume)")
                    .monospacedDigit()
                    .font(.title2)
                    .frame(width: 40)
                Button { Task { try? await od11.changeVolume(5) } } label: {
                    Image(systemName: "speaker.plus")
                }
            }
        }

        GroupBox("EQ") {
            HStack {
                Button { Task { try? await od11.setBassBoost(true) } } label: {
                    Text("Bass+")
                }
                .buttonStyle(.bordered)
                Button { Task { try? await od11.setTrebleBoost(true) } } label: {
                    Text("Treble+")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
