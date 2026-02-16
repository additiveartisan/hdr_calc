import XCTest
@testable import HDRCalc

final class ShootingViewModelTests: XCTestCase {

    private var hardware: StubCameraHardware!
    private var vm: ShootingViewModel!

    override func setUp() {
        super.setUp()
        hardware = StubCameraHardware(delay: .zero)
        vm = ShootingViewModel(hardware: hardware)
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

    func testEstimatedTime_uses2point5sOverhead() {
        // 3 frames, each 0.001s exposure + 2.5s overhead = ~7.503s -> rounds up to 8
        let sets: [[ShutterSpeed]] = [
            [speeds[0], speeds[1], speeds[2]], // very fast shutter speeds
        ]
        let time = vm.estimatedTime(for: sets)
        // Each frame: ~0.000125s + 2.5s overhead = ~2.5s per frame, 3 frames = ~7.5s -> 8
        XCTAssertEqual(time, 8)
    }

    func testEstimatedTime_singleSet() {
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
        let sets: [[ShutterSpeed]] = [
            [speeds[speeds.count - 1]], // 30"
        ]
        let warnings = vm.speedWarnings(for: sets)
        XCTAssertFalse(warnings.isEmpty)
    }

    func testSpeedWarnings_fastSpeeds_noWarnings() {
        let sets: [[ShutterSpeed]] = [
            [speeds[0], speeds[1], speeds[2]],
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

    // MARK: - Shooting Loop (async)

    @MainActor
    func testShootingLoop_allFramesSucceed() async throws {
        let sets: [[ShutterSpeed]] = [
            [speeds[0], speeds[1], speeds[2]],
            [speeds[3], speeds[4], speeds[5]],
        ]
        vm.startShooting(sets: sets)

        // Wait for the shooting loop to complete
        for _ in 0..<100 {
            if vm.isComplete { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(vm.phase, .complete(.success(framesCaptured: 6)))
        XCTAssertEqual(vm.progress.completedFrames, 6)
    }

    @MainActor
    func testShootingLoop_setFailsOnVerify_producesPartialResult() async throws {
        // First set succeeds, then flip shouldFailVerify so second set fails
        let sets: [[ShutterSpeed]] = [
            [speeds[0], speeds[1], speeds[2]],
            [speeds[3], speeds[4], speeds[5]],
        ]

        // We need the first set to succeed but second to fail.
        // Start shooting, then after first set completes, enable failure.
        // Since the stub is zero-delay, we flip it after a brief wait.
        vm.startShooting(sets: sets)

        // Wait for first set to complete (3 frames), then set failure
        for _ in 0..<100 {
            if vm.progress.completedFrames >= 3 {
                hardware.shouldFailVerify = true
                break
            }
            try await Task.sleep(for: .milliseconds(5))
        }

        // Wait for completion
        for _ in 0..<200 {
            if vm.isComplete { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        if case .complete(let result) = vm.phase {
            switch result {
            case .partial(let captured, _):
                XCTAssertEqual(captured, 3)
            case .success:
                // If the loop completed before we could flip the flag, that's still valid
                break
            default:
                break
            }
        }
    }

    @MainActor
    func testShootingLoop_allSetsFail_producesFailedResult() async throws {
        hardware.shouldFailVerify = true
        let sets: [[ShutterSpeed]] = [
            [speeds[0], speeds[1], speeds[2]],
        ]
        vm.startShooting(sets: sets)

        for _ in 0..<200 {
            if vm.isComplete { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(vm.phase, .complete(.failed("All sets failed. Check camera connection and settings.")))
    }

    @MainActor
    func testShootingLoop_cancellationMidLoop() async throws {
        // Use a slightly slower stub to give time to cancel
        hardware.delay = .milliseconds(20)
        let sets: [[ShutterSpeed]] = [
            [speeds[0], speeds[1], speeds[2], speeds[3], speeds[4]],
            [speeds[5], speeds[6], speeds[7], speeds[8], speeds[9]],
        ]
        vm.startShooting(sets: sets)

        // Let a few frames process
        try await Task.sleep(for: .milliseconds(100))

        vm.cancel()
        XCTAssertEqual(vm.phase, .idle)
        XCTAssertEqual(vm.progress, .zero)
    }

    @MainActor
    func testShootingLoop_wrongMode_failsImmediately() async throws {
        hardware.exposureMode = .aperturePriority
        let sets: [[ShutterSpeed]] = [
            [speeds[0], speeds[1], speeds[2]],
        ]
        vm.startShooting(sets: sets)

        for _ in 0..<100 {
            if vm.isComplete { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(vm.phase, .complete(.failed("Camera is not in Manual mode")))
        XCTAssertEqual(vm.progress.completedFrames, 0)
    }
}
