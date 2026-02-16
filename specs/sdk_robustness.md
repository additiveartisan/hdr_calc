# SDK Robustness: Address Sony Camera Remote API Concerns

## Context

Research into the Sony Camera Remote SDK revealed four reliability concerns with the planned WiFi shooting workflow (set shutter speed, verify, capture, repeat). These need to be addressed in the architecture now so the robustness is built in when real SDK calls replace the stubs.

## Concerns Addressed

1. **WiFi latency**: 1.5s per-frame overhead is optimistic; 2.5s is realistic
2. **Silent shutter speed failures**: Camera sometimes ignores property changes; need verify + retry
3. **Buffer blocking**: Must wait for capture completion before next frame
4. **Manual mode required**: Camera must be in M mode for shutter control to work

## Changes

### 1. `SonyCameraTypes.swift` -- New types and protocol

Add `CameraHardwareProtocol` with four methods (the SDK surface area):
- `readExposureMode() async throws -> ExposureMode`
- `setShutterSpeed(_ speed:) async throws`
- `readShutterSpeed() async throws -> ShutterSpeed` (verify read-back)
- `captureAndWaitForBuffer() async throws`

Add supporting types:
- `ExposureMode` enum: `.manual`, `.aperturePriority`, `.shutterPriority`, `.programAuto`, `.unknown`
- `FrameStatus` enum on `ShootingProgress`: `.idle`, `.settingShutter(ShutterSpeed)`, `.verifyingShutter(attempt:maxAttempts:)`, `.capturing(ShutterSpeed)`, `.waitingForBuffer`
- `ConnectionState.wrongMode(DiscoveredCamera, ExposureMode)` case (+ equality)

Add `StubCameraHardware` class conforming to the protocol. Stateful (`final class`, `@unchecked Sendable`) so `readShutterSpeed()` returns what was set. Exposes `shouldFailVerify` and `exposureMode` for test injection.

### 2. `ShootingViewModel.swift` -- Verify-retry loop and updated estimate

- Add `init(hardware: CameraHardwareProtocol = StubCameraHardware())`
- Change overhead constant from `1.5` to `2.5` (`static let perFrameOverheadSeconds: Double = 2.5`)
- Add `static let maxShutterRetries: Int = 3`
- Replace `simulateProgress()` with `executeShootingLoop()` that per-frame does:
  1. Set shutter speed via protocol
  2. Read back and verify (retry up to 3x on mismatch)
  3. Capture via protocol (waits for buffer)
  4. Update `progress.currentFrameStatus` at each step
- Failed frames are skipped (not fatal); result reflects partial completion

### 3. `CameraConnectionService.swift` -- Manual mode verification

- Add `init(hardware: CameraHardwareProtocol = StubCameraHardware())`
- Update `connect(to:)`: during `.modeCheck`, call `hardware.readExposureMode()`. Transition to `.connected` if manual, `.wrongMode` if not.
- Add `retryModeCheck()` for re-checking after user switches the dial

### 4. `CameraConnectView.swift` -- Wrong mode UI

- Add `.wrongMode` case to the state switch
- Show orange `dial.low.fill` icon, "Set Camera to Manual Mode" title, explanation text, and "Check Again" button that calls `service.retryModeCheck()`

### 5. `ShootProgressView.swift` -- Per-frame status label

- Add `frameStatusLabel` below frame count during shooting
- Shows current step: "Setting shutter to 1/500", "Verifying shutter (attempt 2/3)", "Capturing at 1/500", "Waiting for camera buffer"

### 6. `HDRCalcApp.swift` -- Shared hardware instance

- Create one `StubCameraHardware` and inject into both `CameraConnectionService` and `ShootingViewModel`

## Files Modified

| File | Change |
|---|---|
| `SonyCameraTypes.swift` | Protocol, ExposureMode, FrameStatus, StubCameraHardware, .wrongMode case |
| `ShootingViewModel.swift` | init(hardware:), 2.5s overhead, verify-retry loop, frame status updates |
| `CameraConnectionService.swift` | init(hardware:), mode check via protocol, retryModeCheck() |
| `CameraConnectView.swift` | .wrongMode case + wrongModeView |
| `ShootProgressView.swift` | frameStatusLabel |
| `HDRCalcApp.swift` | Shared hardware wiring |

## Tests

Update existing test files to use `init(hardware:)`:

**ShootingViewModelTests.swift**:
- Update `setUp` to inject `StubCameraHardware`
- Add test for 2.5s overhead constant
- All existing tests continue to pass (default stub)

**CameraConnectionServiceTests.swift**:
- Update `setUp` to inject `StubCameraHardware`
- Add: `testConnect_manualMode_connects` (async, verify `.connected`)
- Add: `testConnect_wrongMode_showsWrongMode` (set stub to `.aperturePriority`)
- Add: `testRetryModeCheck_succeeds` (switch stub mode, verify `.connected`)

**SonyCameraTypesTests.swift**:
- Add: `testConnectionState_wrongMode_equality`
- Add: `testFrameStatus_values`

## Verification

- Build for simulator
- Fresh connect: should show checkmark + auto-dismiss (stub returns `.manual`)
- Change stub `exposureMode` to `.aperturePriority` to test wrong-mode screen
- Run full shooting flow: progress view shows per-frame status labels
- Run all tests
