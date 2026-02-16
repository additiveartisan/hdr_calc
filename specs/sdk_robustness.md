# SDK Robustness: Address Sony Camera Remote API Concerns

## Context

Research into the Sony Camera Remote SDK revealed four reliability concerns with the planned WiFi shooting workflow (set shutter speed, verify, capture, repeat). These need to be addressed in the architecture now so the robustness is built in when real SDK calls replace the stubs.

## Concerns Addressed

1. **WiFi latency**: 1.5s per-frame overhead is optimistic; 2.5s is realistic
2. **Silent shutter speed failures**: Camera sometimes ignores property changes; need verify + retry
3. **Buffer blocking**: Must wait for capture completion before next frame
4. **Manual mode required**: Camera must be in M mode for shutter control to work

## Changes

### 1. `CameraHardware.swift` (new file) -- Protocol and stub

Add `CameraHardwareProtocol` with four methods (the SDK surface area):
- `readExposureMode() async throws -> ExposureMode`
- `setShutterSpeed(_ speed:) async throws`
- `readShutterSpeed() async throws -> ShutterSpeed` (verify read-back)
- `captureAndWaitForBuffer() async throws`

**Timeout contract**: All methods must complete or throw within their timeout. `captureAndWaitForBuffer` throws `CameraHardwareError.captureTimeout` after 30s. `setShutterSpeed` and `readShutterSpeed` throw after 5s. `readExposureMode` throws after 5s. Stubs ignore timeouts; real SDK implementation enforces them via `Task.sleep` + cancellation or `withThrowingTaskGroup`.

Add `StubCameraHardware` class conforming to the protocol. Stateful (`final class`, `@unchecked Sendable`) so `readShutterSpeed()` returns what was set. Exposes `shouldFailVerify`, `exposureMode`, and `delay` (default small, zero for tests) for test injection.

### 2. `SonyCameraTypes.swift` -- New supporting types

- `ExposureMode` enum: `.manual`, `.aperturePriority`, `.shutterPriority`, `.programAuto`, `.unknown`
- `CameraHardwareError` enum: `.shutterSpeedMismatch`, `.captureTimeout`, `.wrongExposureMode`, `.disconnected`
- `FrameStatus` enum on `ShootingProgress`: `.idle`, `.settingShutter(ShutterSpeed)`, `.verifyingShutter(attempt:maxAttempts:)`, `.capturing(ShutterSpeed)`, `.waitingForBuffer`
- `ConnectionState.wrongMode(DiscoveredCamera, ExposureMode)` case (+ equality)

### 3. `ShootingViewModel.swift` -- Verify-retry loop and updated estimate

- Add `init(hardware: CameraHardwareProtocol = StubCameraHardware())`
- Change overhead constant from `1.5` to `2.5` (`static let perFrameOverheadSeconds: Double = 2.5`)
- Add `static let maxShutterRetries: Int = 3`
- Add `static let retryDelay: Duration = .milliseconds(300)` -- backoff between retries
- Replace `simulateProgress()` with `executeShootingLoop()`:

**Pre-shoot mode check**: Before firing any frames, call `hardware.readExposureMode()`. If not `.manual`, immediately transition to `.complete(.failed("Camera is not in Manual mode"))`.

**Per-set loop** (not per-frame): For each set, iterate frames. If any frame in a set fails shutter verification after all retries, fail the entire set (an HDR bracket with gaps is unusable). Report as `.partial` with the count of successfully completed sets.

**Per-frame sequence**:
1. `progress.currentFrameStatus = .settingShutter(speed)`
2. Set shutter speed via protocol
3. Wait `retryDelay`, then read back to verify (retry up to `maxShutterRetries` with `retryDelay` between each)
4. Log mismatch on verify failure (requested vs actual) via `os_log` for future hardware debugging
5. On verify success: `progress.currentFrameStatus = .capturing(speed)`, call `captureAndWaitForBuffer()`
6. On hardware throw (any method): treat as set failure, surface error message

**Connection loss**: Any `CameraHardwareError.disconnected` or unexpected throw from hardware methods transitions to `.complete(.failed("Camera disconnected. Reconnect and retry."))`.

### 4. `CameraConnectionService.swift` -- Manual mode verification

- Add `init(hardware: CameraHardwareProtocol = StubCameraHardware())`
- Update `connect(to:)`: during `.modeCheck`, call `hardware.readExposureMode()`. Transition to `.connected` if manual, `.wrongMode` if not. On throw, transition to `.error("Could not read camera mode")`.
- Add `retryModeCheck()` for re-checking after user switches the dial

### 5. `CameraConnectView.swift` -- Wrong mode UI

- Add `.wrongMode` case to the state switch
- Show orange `dial.low.fill` icon, "Set Camera to Manual Mode" title, explanation text, and "Check Again" button that calls `service.retryModeCheck()`

### 6. `ShootProgressView.swift` -- Per-frame status label

- Add `frameStatusLabel` below frame count during shooting
- Shows current step: "Setting shutter to 1/500", "Verifying shutter (attempt 2/3)", "Capturing at 1/500", "Waiting for camera buffer"

### 7. `HDRCalcApp.swift` -- Shared hardware instance

- Create one `StubCameraHardware` and inject into both `CameraConnectionService` and `ShootingViewModel`

## Files Modified

| File | Change |
|---|---|
| `CameraHardware.swift` (new) | Protocol, StubCameraHardware class |
| `SonyCameraTypes.swift` | ExposureMode, CameraHardwareError, FrameStatus, .wrongMode case |
| `ShootingViewModel.swift` | init(hardware:), 2.5s overhead, pre-shoot mode check, set-level verify-retry loop, retry backoff, connection loss handling |
| `CameraConnectionService.swift` | init(hardware:), mode check via protocol, retryModeCheck() |
| `CameraConnectView.swift` | .wrongMode case + wrongModeView |
| `ShootProgressView.swift` | frameStatusLabel |
| `HDRCalcApp.swift` | Shared hardware wiring |

## Tests

All test stubs use `StubCameraHardware(delay: .zero)` for fast execution.

**ShootingViewModelTests.swift**:
- Update `setUp` to inject `StubCameraHardware(delay: .zero)`
- Add: `testEstimatedTime_uses2point5sOverhead`
- Add: `testShootingLoop_allFramesSucceed` (async, inject stub, verify `.complete(.success(...))`)
- Add: `testShootingLoop_setFailsOnVerify_producesPartialResult` (set `shouldFailVerify = true`)
- Add: `testShootingLoop_allSetsFail_producesFailedResult`
- Add: `testShootingLoop_cancellationMidLoop`
- Add: `testShootingLoop_wrongMode_failsImmediately` (set stub mode to `.aperturePriority`)
- All existing tests continue to pass (default stub)

**CameraConnectionServiceTests.swift**:
- Update `setUp` to inject `StubCameraHardware(delay: .zero)`
- Add: `testConnect_manualMode_connects` (async, verify `.connected`)
- Add: `testConnect_wrongMode_showsWrongMode` (set stub to `.aperturePriority`)
- Add: `testConnect_modeCheckThrows_showsError`
- Add: `testRetryModeCheck_succeeds` (switch stub mode, verify `.connected`)

**SonyCameraTypesTests.swift**:
- Add: `testConnectionState_wrongMode_equality`
- Add: `testFrameStatus_settingShutter`
- Add: `testFrameStatus_verifyingShutter`

## Verification

- Build for simulator
- Fresh connect: should show checkmark + auto-dismiss (stub returns `.manual`)
- Change stub `exposureMode` to `.aperturePriority` to test wrong-mode screen
- Run full shooting flow: progress view shows per-frame status labels cycling through states
- Run all tests (should complete quickly with zero-delay stubs)

## Deferred (Real SDK Integration)

- Enforce actual timeouts in real `CameraHardwareProtocol` implementation (C++ SDK bridge with serial dispatch queue)
- WiFi reconnection recovery during shooting (detect drop, pause, offer reconnect)
- Tune `perFrameOverheadSeconds` and `retryDelay` with real-world measurements
- Integration test script for real hardware
