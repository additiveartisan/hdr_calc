import Foundation

protocol CameraHardwareProtocol: Sendable {
    func readExposureMode() async throws -> ExposureMode
    func setShutterSpeed(_ speed: ShutterSpeed) async throws
    func readShutterSpeed() async throws -> ShutterSpeed
    func captureAndWaitForBuffer() async throws
}

final class StubCameraHardware: CameraHardwareProtocol, @unchecked Sendable {
    var exposureMode: ExposureMode = .manual
    var shouldFailVerify = false
    var delay: Duration

    private var currentSpeed: ShutterSpeed?

    init(delay: Duration = .milliseconds(50)) {
        self.delay = delay
    }

    func readExposureMode() async throws -> ExposureMode {
        if delay > .zero { try? await Task.sleep(for: delay) }
        return exposureMode
    }

    func setShutterSpeed(_ speed: ShutterSpeed) async throws {
        if delay > .zero { try? await Task.sleep(for: delay) }
        currentSpeed = speed
    }

    func readShutterSpeed() async throws -> ShutterSpeed {
        if delay > .zero { try? await Task.sleep(for: delay) }
        if shouldFailVerify {
            // Return a different speed to simulate mismatch
            let wrongIndex = ((currentSpeed?.index ?? 0) + 1) % speeds.count
            return speeds[wrongIndex]
        }
        return currentSpeed ?? speeds[0]
    }

    func captureAndWaitForBuffer() async throws {
        if delay > .zero { try? await Task.sleep(for: delay) }
    }
}
