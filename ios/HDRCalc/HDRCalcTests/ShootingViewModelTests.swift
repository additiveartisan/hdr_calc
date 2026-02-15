import XCTest
@testable import HDRCalc

final class ShootingViewModelTests: XCTestCase {

    private var vm: ShootingViewModel!

    override func setUp() {
        super.setUp()
        vm = ShootingViewModel()
    }

    // MARK: - Initial State

    func testInitialPhase_isIdle() {
        XCTAssertEqual(vm.phase, .idle)
    }

    func testInitialProgress_isZero() {
        XCTAssertEqual(vm.progress, .zero)
    }

    // MARK: - Phase Booleans

    func testIsShooting_trueWhenShooting() {
        vm._setPhaseForTesting(.shooting)
        XCTAssertTrue(vm.isShooting)
    }

    func testIsShooting_falseWhenIdle() {
        XCTAssertFalse(vm.isShooting)
    }

    func testIsComplete_trueWhenSuccess() {
        vm._setPhaseForTesting(.complete(.success(framesCaptured: 15)))
        XCTAssertTrue(vm.isComplete)
    }

    func testIsComplete_trueWhenPartial() {
        vm._setPhaseForTesting(.complete(.partial(framesCaptured: 10, totalExpected: 15)))
        XCTAssertTrue(vm.isComplete)
    }

    func testIsComplete_falseWhenShooting() {
        vm._setPhaseForTesting(.shooting)
        XCTAssertFalse(vm.isComplete)
    }

    func testIsPaused_trueWhenPaused() {
        vm._setPhaseForTesting(.paused)
        XCTAssertTrue(vm.isPaused)
    }

    func testIsPaused_falseWhenShooting() {
        vm._setPhaseForTesting(.shooting)
        XCTAssertFalse(vm.isPaused)
    }

    // MARK: - Estimated Time

    func testEstimatedTime_singleSet() {
        // 5 frames, each about 2 seconds average
        let sets: [[ShutterSpeed]] = [
            [speeds[18], speeds[15], speeds[12], speeds[9], speeds[6]],
        ]
        let time = vm.estimatedTime(for: sets)
        XCTAssertGreaterThan(time, 0)
    }

    func testEstimatedTime_multipleSets() {
        let sets: [[ShutterSpeed]] = [
            [speeds[18], speeds[15], speeds[12], speeds[9], speeds[6]],
            [speeds[6], speeds[3], speeds[0], speeds[0], speeds[0]],
        ]
        let time = vm.estimatedTime(for: sets)
        XCTAssertGreaterThan(time, vm.estimatedTime(for: [sets[0]]))
    }

    func testEstimatedTime_empty() {
        let time = vm.estimatedTime(for: [])
        XCTAssertEqual(time, 0)
    }

    // MARK: - Formatted Estimated Time

    func testFormattedEstimatedTime_seconds() {
        let formatted = vm.formattedEstimatedTime(45)
        XCTAssertEqual(formatted, "45s")
    }

    func testFormattedEstimatedTime_minutes() {
        let formatted = vm.formattedEstimatedTime(125)
        XCTAssertEqual(formatted, "2m 5s")
    }

    func testFormattedEstimatedTime_zero() {
        let formatted = vm.formattedEstimatedTime(0)
        XCTAssertEqual(formatted, "0s")
    }

    // MARK: - Speed Warnings

    func testSpeedWarnings_slowSpeeds() {
        // Sets with very slow shutter speeds (30")
        let sets: [[ShutterSpeed]] = [
            [speeds[speeds.count - 1]], // 30"
        ]
        let warnings = vm.speedWarnings(for: sets)
        XCTAssertFalse(warnings.isEmpty)
    }

    func testSpeedWarnings_fastSpeeds_noWarnings() {
        // Sets with fast shutter speeds only
        let sets: [[ShutterSpeed]] = [
            [speeds[0], speeds[1], speeds[2]], // 1/8000, 1/6400, 1/5000
        ]
        let warnings = vm.speedWarnings(for: sets)
        XCTAssertTrue(warnings.isEmpty)
    }

    // MARK: - Start Shooting

    func testStartShooting_initializesProgress() {
        let sets: [[ShutterSpeed]] = [
            [speeds[0], speeds[1], speeds[2], speeds[3], speeds[4]],
            [speeds[4], speeds[5], speeds[6], speeds[7], speeds[8]],
        ]
        vm.startShooting(sets: sets)
        XCTAssertEqual(vm.phase, .shooting)
        XCTAssertEqual(vm.progress.totalFrames, 10)
        XCTAssertEqual(vm.progress.totalSets, 2)
        XCTAssertEqual(vm.progress.completedFrames, 0)
        XCTAssertEqual(vm.progress.currentSet, 1)
    }

    // MARK: - Cancel

    func testCancel_resetsToIdle() {
        vm._setPhaseForTesting(.shooting)
        vm.cancel()
        XCTAssertEqual(vm.phase, .idle)
        XCTAssertEqual(vm.progress, .zero)
    }

    // MARK: - Dismiss

    func testDismiss_resetsToIdle() {
        vm._setPhaseForTesting(.complete(.success(framesCaptured: 15)))
        vm.dismiss()
        XCTAssertEqual(vm.phase, .idle)
        XCTAssertEqual(vm.progress, .zero)
    }

    // MARK: - Retry Remaining

    func testRetryRemaining_fromPartial() {
        vm._setPhaseForTesting(.complete(.partial(framesCaptured: 10, totalExpected: 15)))
        vm.progress = ShootingProgress(completedFrames: 10, totalFrames: 15, currentSet: 2, totalSets: 3)
        vm.retryRemaining()
        XCTAssertEqual(vm.phase, .shooting)
    }
}
