import XCTest
@testable import HDRCalc

final class CameraConnectionServiceTests: XCTestCase {

    private var hardware: StubCameraHardware!
    private var service: CameraConnectionService!

    override func setUp() {
        super.setUp()
        hardware = StubCameraHardware(delay: .zero)
        service = CameraConnectionService(hardware: hardware)
    }

    // MARK: - Initial State

    func testInitialState_isDisconnected() {
        XCTAssertEqual(service.connectionState, .disconnected)
    }

    func testInitialState_noCameras() {
        XCTAssertTrue(service.discoveredCameras.isEmpty)
    }

    func testInitialState_isConnectedFalse() {
        XCTAssertFalse(service.isConnected)
    }

    func testInitialState_connectedCameraNameNil() {
        XCTAssertNil(service.connectedCameraName)
    }

    // MARK: - Discovery

    func testStartDiscovery_setsDiscovering() {
        service.startDiscovery()
        XCTAssertEqual(service.connectionState, .discovering)
    }

    func testStopDiscovery_returnsToDisconnected() {
        service.startDiscovery()
        service.stopDiscovery()
        XCTAssertEqual(service.connectionState, .disconnected)
    }

    func testStopDiscovery_whenConnected_staysConnected() {
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        service._setStateForTesting(.connected(camera))
        service.stopDiscovery()
        XCTAssertEqual(service.connectionState, .connected(camera))
    }

    // MARK: - Connect

    func testConnect_setsConnecting() {
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        service.connect(to: camera)
        XCTAssertEqual(service.connectionState, .connecting(camera))
    }

    // MARK: - Disconnect

    func testDisconnect_clearsState() {
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        service._setStateForTesting(.connected(camera))
        service.disconnect()
        XCTAssertEqual(service.connectionState, .disconnected)
    }

    // MARK: - Computed Properties

    func testIsConnected_trueWhenConnected() {
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        service._setStateForTesting(.connected(camera))
        XCTAssertTrue(service.isConnected)
    }

    func testIsConnected_falseWhenDiscovering() {
        service._setStateForTesting(.discovering)
        XCTAssertFalse(service.isConnected)
    }

    func testIsConnected_falseWhenConnecting() {
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        service._setStateForTesting(.connecting(camera))
        XCTAssertFalse(service.isConnected)
    }

    func testConnectedCameraName_returnsNameWhenConnected() {
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        service._setStateForTesting(.connected(camera))
        XCTAssertEqual(service.connectedCameraName, "Alpha 7R V")
    }

    func testConnectedCameraName_nilWhenDisconnected() {
        XCTAssertNil(service.connectedCameraName)
    }

    // MARK: - Error State

    func testErrorState() {
        service._setStateForTesting(.error("Connection timed out"))
        XCTAssertEqual(service.connectionState, .error("Connection timed out"))
        XCTAssertFalse(service.isConnected)
    }

    // MARK: - Retry

    func testRetry_fromError_setsDiscovering() {
        service._setStateForTesting(.error("Failed"))
        service.retry()
        XCTAssertEqual(service.connectionState, .discovering)
    }

    // MARK: - Mode Check (async)

    @MainActor
    func testConnect_manualMode_connects() async throws {
        hardware.exposureMode = .manual
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        service.connect(to: camera)

        for _ in 0..<200 {
            if service.isConnected { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(service.connectionState, .connected(camera))
    }

    @MainActor
    func testConnect_wrongMode_showsWrongMode() async throws {
        hardware.exposureMode = .aperturePriority
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        service.connect(to: camera)

        for _ in 0..<200 {
            if case .wrongMode = service.connectionState { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(service.connectionState, .wrongMode(camera, .aperturePriority))
    }

    @MainActor
    func testConnect_modeCheckThrows_showsError() async throws {
        // Create a throwing hardware stub
        let throwingHardware = ThrowingStubCameraHardware()
        let throwingService = CameraConnectionService(hardware: throwingHardware)
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        throwingService.connect(to: camera)

        for _ in 0..<200 {
            if case .error = throwingService.connectionState { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(throwingService.connectionState, .error("Could not read camera mode"))
    }

    @MainActor
    func testRetryModeCheck_succeeds() async throws {
        hardware.exposureMode = .aperturePriority
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        service._setStateForTesting(.wrongMode(camera, .aperturePriority))

        // Switch to manual, then retry
        hardware.exposureMode = .manual
        service.retryModeCheck()

        for _ in 0..<200 {
            if service.isConnected { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(service.connectionState, .connected(camera))
    }
}

// Helper: a hardware stub that always throws
private final class ThrowingStubCameraHardware: CameraHardwareProtocol, @unchecked Sendable {
    func readExposureMode() async throws -> ExposureMode {
        throw CameraHardwareError.disconnected
    }
    func setShutterSpeed(_ speed: ShutterSpeed) async throws {
        throw CameraHardwareError.disconnected
    }
    func readShutterSpeed() async throws -> ShutterSpeed {
        throw CameraHardwareError.disconnected
    }
    func captureAndWaitForBuffer() async throws {
        throw CameraHardwareError.disconnected
    }
}
