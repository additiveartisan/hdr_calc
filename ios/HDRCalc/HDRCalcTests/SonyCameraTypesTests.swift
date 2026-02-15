import XCTest
@testable import HDRCalc

final class SonyCameraTypesTests: XCTestCase {

    // MARK: - ShootingProgress.fractionComplete

    func testFractionComplete_zero() {
        let progress = ShootingProgress.zero
        XCTAssertEqual(progress.fractionComplete, 0)
    }

    func testFractionComplete_partial() {
        let progress = ShootingProgress(completedFrames: 8, totalFrames: 15, currentSet: 2, totalSets: 3)
        XCTAssertEqual(progress.fractionComplete, 8.0 / 15.0, accuracy: 0.001)
    }

    func testFractionComplete_complete() {
        let progress = ShootingProgress(completedFrames: 15, totalFrames: 15, currentSet: 3, totalSets: 3)
        XCTAssertEqual(progress.fractionComplete, 1.0)
    }

    func testFractionComplete_zeroTotal() {
        let progress = ShootingProgress(completedFrames: 0, totalFrames: 0, currentSet: 0, totalSets: 0)
        XCTAssertEqual(progress.fractionComplete, 0)
    }

    // MARK: - ShootingProgress.setProgress

    func testSetProgress() {
        let progress = ShootingProgress(completedFrames: 8, totalFrames: 15, currentSet: 2, totalSets: 3)
        XCTAssertEqual(progress.setProgress, "Set 2 of 3")
    }

    // MARK: - ShootingProgress.frameProgress

    func testFrameProgress() {
        let progress = ShootingProgress(completedFrames: 8, totalFrames: 15, currentSet: 2, totalSets: 3)
        XCTAssertEqual(progress.frameProgress, "8 of 15 frames")
    }

    // MARK: - ShootingProgress.zero

    func testZero() {
        let progress = ShootingProgress.zero
        XCTAssertEqual(progress.completedFrames, 0)
        XCTAssertEqual(progress.totalFrames, 0)
        XCTAssertEqual(progress.currentSet, 0)
        XCTAssertEqual(progress.totalSets, 0)
    }

    // MARK: - ConnectionState equality

    func testConnectionState_disconnected() {
        let state = ConnectionState.disconnected
        XCTAssertEqual(state, .disconnected)
    }

    func testConnectionState_discovering() {
        let state = ConnectionState.discovering
        XCTAssertEqual(state, .discovering)
    }

    func testConnectionState_connected() {
        let camera = DiscoveredCamera(id: "test", name: "Alpha 7R V", address: "192.168.1.1")
        let state = ConnectionState.connected(camera)
        if case .connected(let c) = state {
            XCTAssertEqual(c.name, "Alpha 7R V")
        } else {
            XCTFail("Expected .connected state")
        }
    }

    // MARK: - ShootingResult

    func testShootingResult_success() {
        let result = ShootingResult.success(framesCaptured: 15)
        if case .success(let count) = result {
            XCTAssertEqual(count, 15)
        } else {
            XCTFail("Expected .success")
        }
    }

    func testShootingResult_partial() {
        let result = ShootingResult.partial(framesCaptured: 10, totalExpected: 15)
        if case .partial(let captured, let total) = result {
            XCTAssertEqual(captured, 10)
            XCTAssertEqual(total, 15)
        } else {
            XCTFail("Expected .partial")
        }
    }

    // MARK: - SpeedWarning

    func testSpeedWarning_hasMessage() {
        let warning = SpeedWarning(message: "Slow shutter speeds may cause blur", severity: .caution)
        XCTAssertEqual(warning.message, "Slow shutter speeds may cause blur")
        XCTAssertEqual(warning.severity, .caution)
    }
}
