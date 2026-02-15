import Foundation

@Observable
final class CameraConnectionService {
    var connectionState: ConnectionState = .disconnected
    var discoveredCameras: [DiscoveredCamera] = []

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

        // Stub: simulate connection sequence
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            guard case .connecting(let c) = connectionState, c.id == camera.id else { return }
            connectionState = .modeCheck(camera)

            try? await Task.sleep(for: .seconds(0.5))
            guard case .modeCheck(let c) = connectionState, c.id == camera.id else { return }
            connectionState = .connected(camera)
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
