import Foundation

@Observable
final class CameraConnectionService {
    var connectionState: ConnectionState = .disconnected
    var discoveredCameras: [DiscoveredCamera] = []

    private let hardware: any CameraHardwareProtocol

    init(hardware: any CameraHardwareProtocol = StubCameraHardware()) {
        self.hardware = hardware
    }

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    var connectedCameraName: String? {
        if case .connected(let camera) = connectionState { return camera.name }
        return nil
    }

    func startDiscovery() {
        connectionState = .discovering
        discoveredCameras = []

        // Stub: simulate cameras appearing after a delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard case .discovering = connectionState else { return }
            discoveredCameras = [
                DiscoveredCamera(id: "stub-1", name: "ILCE-7RM5", address: "192.168.122.1"),
            ]
        }
    }

    func stopDiscovery() {
        guard case .connected = connectionState else {
            connectionState = .disconnected
            discoveredCameras = []
            return
        }
    }

    func connect(to camera: DiscoveredCamera) {
        connectionState = .connecting(camera)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            guard case .connecting(let c) = connectionState, c.id == camera.id else { return }
            connectionState = .modeCheck(camera)
            await checkMode(for: camera)
        }
    }

    func retryModeCheck() {
        guard case .wrongMode(let camera, _) = connectionState else { return }
        connectionState = .modeCheck(camera)

        Task { @MainActor in
            await checkMode(for: camera)
        }
    }

    private func checkMode(for camera: DiscoveredCamera) async {
        do {
            let mode = try await hardware.readExposureMode()
            guard case .modeCheck(let c) = connectionState, c.id == camera.id else { return }
            if mode == .manual {
                connectionState = .connected(camera)
            } else {
                connectionState = .wrongMode(camera, mode)
            }
        } catch {
            guard case .modeCheck(let c) = connectionState, c.id == camera.id else { return }
            connectionState = .error("Could not read camera mode")
        }
    }

    func disconnect() {
        connectionState = .disconnected
        discoveredCameras = []
    }

    func retry() {
        startDiscovery()
    }

    // Test-only: set state synchronously without async delays
    func _setStateForTesting(_ state: ConnectionState) {
        connectionState = state
    }
}
