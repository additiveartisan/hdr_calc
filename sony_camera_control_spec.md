# Sony Camera Control Integration for HDR Calc iOS

## Context

HDR Calc iOS is a complete bracket calculator with camera metering, stub-based camera connection UI, and a robustness layer (verify-retry shooting loop, manual mode enforcement, per-frame status tracking). The next milestone is replacing stubs with real Sony camera control over WiFi.

**Why rocc?** The official Sony Camera Remote SDK is C++ only (Windows/macOS/Linux desktop). rocc is an MIT-licensed Swift framework that reverse-engineers Sony's PTP/IP protocol, providing shutter speed control and shutter release over WiFi. It's the only viable path for iOS.

## What's Already Built

The stub UI scaffolding and SDK robustness layer are complete and tested (74 tests passing). These provide the integration surface for real camera control.

| Component | File(s) | Status |
|-----------|---------|--------|
| Hardware abstraction | `CameraHardware.swift` | `CameraHardwareProtocol` with 4 methods, `StubCameraHardware` for testing |
| Type system | `SonyCameraTypes.swift` | `ExposureMode`, `CameraHardwareError`, `FrameStatus`, `ConnectionState` (incl. `.wrongMode`) |
| Shooting loop | `ShootingViewModel.swift` | `executeShootingLoop()` with pre-shoot mode check, per-frame set/verify/capture, 3-retry verify with 300ms backoff, os_log diagnostics, set-level failure (partial result), disconnection handling |
| Connection service | `CameraConnectionService.swift` | Stub discovery, `connect(to:)` with mode check via protocol, `retryModeCheck()` |
| Connect UI | `CameraConnectView.swift` | All states: disconnected, discovering, connecting, modeCheck, connected, wrongMode (with "Check Again"), error |
| Confirm UI | `ShootConfirmView.swift` | Set count, total exposures, estimated time, slow-speed warnings, exposure set preview |
| Progress UI | `ShootProgressView.swift` | Progress ring, set/frame counts, per-frame status label (setting/verifying/capturing/buffer), complete/partial/failed/cancelled states |
| App wiring | `HDRCalcApp.swift` | Shared `StubCameraHardware` injected into both service and view model |
| Calculator UI | `ContentView.swift` | "Connect Camera" button, "Shoot All Sets" button (visible when connected), sheet presentations |

**Key architectural decision**: `CameraHardwareProtocol` is the boundary between app logic and SDK. `ShootingViewModel` and `CameraConnectionService` depend only on this protocol. The real SDK implementation (`RoccCameraHardware`) will conform to it, requiring zero changes to the shooting loop, connection flow, or UI.

## Workflow (User Perspective)

1. **Connect**: Tap "Connect Camera" in inputs section. App discovers Sony cameras on WiFi via SSDP. Tap camera name to connect. App validates camera is in Manual mode and queries available shutter speeds.
2. **Meter + Configure**: Meter scene shadows/highlights (existing), set AEB frames and EV spacing (existing). Changing settings while connected updates the bracket plan live.
3. **Review + Confirm**: Tap "Shoot All Sets" button (appears in results when camera connected). Confirmation sheet shows: "3 sets, 15 exposures. Estimated time: ~38s." Any speeds not available on the camera are flagged with nearest substitutes.
4. **Shoot**: App begins bracket sequence. Progress overlay shows current set/frame/speed with status labels cycling through states. Haptic tap on each successful capture. If disconnected, auto-pauses and shows reconnect prompt.
5. **Done**: Progress shows "Complete: 15 of 15 exposures captured". If partial failure: "8 of 15 frames captured. [Retry Remaining] [Dismiss]". Dismiss returns to calculator.

## Architecture

| Layer | File | Role | Status |
|-------|------|------|--------|
| Hardware protocol | `CameraHardware.swift` | 4-method abstraction + stub | Done |
| Types | `SonyCameraTypes.swift` | ExposureMode, errors, FrameStatus, ConnectionState | Done |
| Speed mapping | `ShutterSpeedMapping.swift` | Our ShutterSpeed to/from rocc ShutterSpeed | **New** |
| Real hardware | `RoccCameraHardware.swift` | Conforms to CameraHardwareProtocol, wraps rocc | **New** |
| Discovery | `SonyCameraDiscovery.swift` | SSDP discovery via rocc's CameraDiscoverer | **New** |
| WiFi monitor | `WiFiMonitor.swift` | NWPathMonitor SSID tracking, auto-pause | **New** |
| Shooting loop | `ShootingViewModel.swift` | Verify-retry loop, mode check, progress tracking | Done (needs haptics, background task, WiFi monitor wiring) |
| Connection service | `CameraConnectionService.swift` | Discovery + connect + mode check | Done (stub discovery replaced in Phase 3) |
| Connect UI | `CameraConnectView.swift` | Discovery list, connection states, wrong mode | Done |
| Confirm UI | `ShootConfirmView.swift` | Pre-shoot review | Done (needs speed validation additions) |
| Progress UI | `ShootProgressView.swift` | Shooting progress overlay | Done (needs pause states) |

## Remaining Implementation Phases

### Phase 1: Validate rocc API

Before writing any code, clone rocc locally and confirm:
- `ShutterSpeed` type has `numerator`/`denominator` properties (or document actual API)
- `performFunction(Shutter.Speed.set, payload:)` accepts a `ShutterSpeed` payload
- `performFunction(StillCapture.take, payload:)` exists and returns on capture complete
- `CameraEvent.shutterSpeed` exposes available speed list
- `isFunctionAvailable(Shutter.Speed.set)` works for mode detection
- Camera status enum values for idle/capturing/saving states

If rocc's ShutterSpeed uses a different representation (string, enum, etc.), revise Phase 2 mapping approach before proceeding.

**Deliverable**: Document of actual rocc API surface with code snippets from the cloned source. No code changes.

### Phase 2: SPM Dependency + Shutter Speed Mapping (TDD)

| File | Action | Detail |
|------|--------|--------|
| `project.pbxproj` | Edit | Add rocc SPM: `https://github.com/simonmitchell/rocc.git` from 2.0.0 |
| `ShutterSpeedMapping.swift` | Create | Extension on `ShutterSpeed` with `.roccShutterSpeed` computed property + `validateSpeeds()` |
| `ShutterSpeedMappingTests.swift` | Create | All 55 speeds map correctly, validation function tests |

**Mapping logic** (label-based, not seconds-based, because labels match Sony's nominal values):
- `"1/1000"` parses to numerator=1, denominator=1000
- `"2\""` parses to numerator=2, denominator=1
- `"0.3\""` parses to numerator=3, denominator=10
- `"1/2"` parses to numerator=1, denominator=2

**Speed validation function** (powers confirmation UI):

```
func validateSpeeds(
    sets: [[ShutterSpeed]],
    available: [RoccShutterSpeed]
) -> SpeedValidationResult
```

Returns which speeds are available, which need substitution, and the nearest available alternative for each unavailable speed. `SpeedValidationResult` contains:
- `allAvailable: Bool`
- `substitutions: [(original: ShutterSpeed, substitute: ShutterSpeed)]`

**Note on type collision**: Module-qualify as `Rocc.ShutterSpeed` in mapping file to avoid ambiguity with our `ShutterSpeed`.

**Tests** (TDD, write RED first):
- `testAllSpeedsMapToRocc` (55 entries, verify numerator/denominator)
- `testRoccSpeedMapBackToOurs` (round-trip for all 55)
- `testValidateSpeeds_allAvailable` (empty substitutions)
- `testValidateSpeeds_someUnavailable` (returns correct substitutions)
- `testValidateSpeeds_nearestSubstituteIsClosest` (verify nearest-match logic)

### Phase 3: RoccCameraHardware + Discovery (real SDK)

| File | Action | Detail |
|------|--------|--------|
| `RoccCameraHardware.swift` | Create | Conforms to `CameraHardwareProtocol`, wraps rocc |
| `SonyCameraDiscovery.swift` | Create | SSDP discovery via rocc's `CameraDiscoverer` |
| `CameraConnectionService.swift` | Edit | Replace stub discovery with `SonyCameraDiscovery` |
| `HDRCalcApp.swift` | Edit | Wire real hardware when camera connected, keep stub as fallback |

#### RoccCameraHardware

Conforms to `CameraHardwareProtocol`. This is the only file that imports rocc.

```
final class RoccCameraHardware: CameraHardwareProtocol, @unchecked Sendable {
    private let camera: Rocc.Camera  // connected camera instance from rocc

    func readExposureMode() async throws -> ExposureMode
    func setShutterSpeed(_ speed: ShutterSpeed) async throws
    func readShutterSpeed() async throws -> ShutterSpeed
    func captureAndWaitForBuffer() async throws
}
```

**Timeout contracts** (enforced via `withThrowingTaskGroup` or `Task.sleep` + cancellation):
- `readExposureMode()`: 5s, throws `CameraHardwareError.disconnected`
- `setShutterSpeed()`: 5s, throws `CameraHardwareError.disconnected`
- `readShutterSpeed()`: 5s, throws `CameraHardwareError.disconnected`
- `captureAndWaitForBuffer()`: shutter duration + 30s buffer, throws `CameraHardwareError.captureTimeout`

**Bridging rocc's callback API to async/await**:
- `performFunction(Shutter.Speed.set, payload:)` bridged via `withCheckedThrowingContinuation`
- `performFunction(StillCapture.take, payload:)` bridged via `withCheckedThrowingContinuation`
- Camera event observation via `CameraEventNotifier` to detect status (idle/capturing/saving)
- Status polling for `captureAndWaitForBuffer()`: after triggering capture, poll events until camera returns to idle state

**Exposure mode mapping**: Map rocc's shooting mode representation to our `ExposureMode` enum.

**Shutter speed read-back**: After `setShutterSpeed()`, the existing verify-retry loop in `ShootingViewModel.executeShootingLoop()` calls `readShutterSpeed()` to confirm. `RoccCameraHardware.readShutterSpeed()` reads the current speed from camera events and maps it back to our `ShutterSpeed` via the mapping layer.

#### SonyCameraDiscovery

Replaces the stub `Task.sleep` discovery in `CameraConnectionService`.

```
@Observable
final class SonyCameraDiscovery {
    var discoveredCameras: [DiscoveredCamera] = []
    private var discoverer: CameraDiscoverer?  // rocc type

    func startDiscovery()    // creates CameraDiscoverer, sets delegate
    func stopDiscovery()     // tears down discoverer
    func connect(to camera: DiscoveredCamera) async throws -> RoccCameraHardware
}
```

Responsibilities:
- `CameraDiscoverer` for SSDP WiFi discovery (delegate-based, bridged to @Observable)
- `connect(to:)` returns a `RoccCameraHardware` instance on success
- Maps rocc's discovered device to our `DiscoveredCamera` (id, name, address)
- Stores camera WiFi SSID at connection time for `WiFiMonitor` comparison

#### CameraConnectionService changes

Replace the stub discovery internals:
- `startDiscovery()` delegates to `SonyCameraDiscovery`
- `connect(to:)` calls `SonyCameraDiscovery.connect(to:)` to get a `RoccCameraHardware`, then calls `hardware.readExposureMode()` for mode check (existing logic, just with real hardware now)
- The `hardware` property switches from `StubCameraHardware` to the `RoccCameraHardware` returned by discovery

**Info.plist keys** (added as build settings in project.pbxproj):
- `NSLocalNetworkUsageDescription`: "HDR Calc discovers Sony cameras on your WiFi network to remotely control exposure bracketing."
- `NSBonjourServices`: `["_ssdp._udp"]` (for SSDP multicast discovery)

### Phase 4: WiFi Monitor

| File | Action | Detail |
|------|--------|--------|
| `WiFiMonitor.swift` | Create | NWPathMonitor wrapper for SSID change detection |
| `ShootingViewModel.swift` | Edit | Wire WiFiMonitor, add pause/resume on SSID change |
| `ShootProgressView.swift` | Edit | Add paused states for disconnect and WiFi switch |

#### WiFiMonitor

```
final class WiFiMonitor: @unchecked Sendable {
    var onSSIDChanged: ((String?) -> Void)?
    private let expectedSSID: String

    init(expectedSSID: String)
    func startMonitoring()
    func stopMonitoring()
}
```

Uses `NWPathMonitor` to observe network changes. Compares current WiFi SSID against stored camera SSID. Calls `onSSIDChanged` when network switches away from camera WiFi.

Requires `com.apple.developer.networking.wifi-info` entitlement and `NEHotspotNetwork.fetchCurrent()` for SSID access.

#### ShootingViewModel changes

- Create `WiFiMonitor` when shooting starts (with SSID from connection)
- On SSID change: set `phase = .paused`, store resume position
- On SSID return: set `phase = .shooting`, resume from stored position
- On `CameraHardwareError.disconnected` during shooting: set `phase = .paused` instead of immediately failing (allow reconnect recovery)
- Stop monitor on completion, cancellation, or dismiss

#### ShootProgressView changes

Add two paused sub-states to the existing `.paused` case:

- **Paused (disconnect)**: Pause icon, "Camera disconnected. Reconnect WiFi to resume." Auto-resume on reconnect.
- **Paused (WiFi switch)**: "iPhone switched WiFi networks. Reconnect to [camera SSID] to resume."

This requires extending `ShootingPhase.paused` to carry a reason, or adding a separate `pauseReason` property to `ShootingViewModel`.

### Phase 5: Haptics + Background Task + Speed Validation

| File | Action | Detail |
|------|--------|--------|
| `ShootingViewModel.swift` | Edit | Add haptic feedback, background task management |
| `ShootConfirmView.swift` | Edit | Add speed validation against camera's available speeds |
| `CameraHardware.swift` | Edit | Add `availableShutterSpeeds()` to protocol |

#### Haptic feedback

Add to `ShootingViewModel.executeShootingLoop()`:
- `UIImpactFeedbackGenerator(style: .light).impactOccurred()` after each successful `captureAndWaitForBuffer()`
- `UINotificationFeedbackGenerator().notificationOccurred(.success)` on `.complete(.success(...))`
- `UINotificationFeedbackGenerator().notificationOccurred(.error)` on `.complete(.failed(...))`
- Haptics respect system settings automatically

#### Background task

Add to `ShootingViewModel`:
- `UIApplication.shared.beginBackgroundTask` called when `executeShootingLoop()` starts
- `UIApplication.shared.endBackgroundTask` called on completion, cancellation, or failure
- If background time expires before completion: cancel the shooting task, set `phase = .complete(.failed("Shooting interrupted. App was suspended."))`, notify user on next foreground

```swift
private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

// In executeShootingLoop(), before the loop:
backgroundTaskID = UIApplication.shared.beginBackgroundTask {
    // Expiration handler
    self.shootingTask?.cancel()
    self.phase = .complete(.failed("Shooting interrupted. App was suspended."))
    UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
    self.backgroundTaskID = .invalid
}

// After loop completes (success, failure, or cancellation):
if backgroundTaskID != .invalid {
    UIApplication.shared.endBackgroundTask(backgroundTaskID)
    backgroundTaskID = .invalid
}
```

#### Speed validation in ShootConfirmView

Add `availableShutterSpeeds() async throws -> [ShutterSpeed]` to `CameraHardwareProtocol`. `StubCameraHardware` returns all 55 speeds. `RoccCameraHardware` queries the camera.

Update `ShootConfirmView`:
- On appear, call `hardware.availableShutterSpeeds()` and run `validateSpeeds()` from the mapping layer
- If any speeds need substitution, show a warning section: "1/6400 not available on this camera, using 1/5000 instead"
- If all speeds available, show nothing extra (current behavior)

### Phase 6: Build + Test

- All existing 74 tests still pass (unchanged, use StubCameraHardware)
- New ShutterSpeedMapping tests pass (all 55 speeds map correctly, plus validation function)
- Project builds with no warnings
- Manual integration test with physical Sony Alpha camera (see test plan below)

## New Files

| File | Target |
|------|--------|
| `HDRCalc/ShutterSpeedMapping.swift` | App |
| `HDRCalc/RoccCameraHardware.swift` | App |
| `HDRCalc/SonyCameraDiscovery.swift` | App |
| `HDRCalc/WiFiMonitor.swift` | App |
| `HDRCalcTests/ShutterSpeedMappingTests.swift` | Tests |

## Files Modified

| File | Change |
|------|--------|
| `project.pbxproj` | rocc SPM dependency, new file references, Info.plist keys, WiFi entitlement |
| `CameraHardware.swift` | Add `availableShutterSpeeds()` to protocol and stub |
| `CameraConnectionService.swift` | Replace stub discovery with SonyCameraDiscovery, swap hardware on connect |
| `ShootingViewModel.swift` | Wire WiFiMonitor, haptic feedback, background task |
| `ShootProgressView.swift` | Paused sub-states (disconnect, WiFi switch) |
| `ShootConfirmView.swift` | Speed validation section |
| `HDRCalcApp.swift` | Wire real hardware from discovery |

## Existing Files (no changes needed)

- `Speeds.swift` -- ShutterSpeed struct (extended in ShutterSpeedMapping.swift)
- `Calculator.swift` -- provides `[[ShutterSpeed]]` sets to shooting loop
- `CameraService.swift` -- AVCaptureSession metering (separate from Sony control)
- `SonyCameraTypes.swift` -- ExposureMode, CameraHardwareError, FrameStatus, ConnectionState already complete
- `CameraConnectView.swift` -- All states already handled including wrongMode
- `ContentView.swift` -- Connect/Shoot buttons already wired
- `Theme.swift` -- No changes needed

## Risks + Mitigations

| Risk | Mitigation |
|------|------------|
| rocc's ShutterSpeed type unverified | Phase 1: clone repo, inspect type before building mapping layer |
| rocc last updated 2020 | PTP/IP protocol is stable; fork if needed for new models |
| Per-shot WiFi latency variable | 2.5s overhead already built in; tune with real measurements |
| Camera must be in M mode | Validated at connection time via `readExposureMode()`, wrongMode UI with "Check Again" already built |
| iOS switches away from camera WiFi | WiFiMonitor tracks SSID via NWPathMonitor, auto-pauses on network change |
| App backgrounded during shoot | beginBackgroundTask for extended execution; fail gracefully if time expires |
| Camera shutter speeds differ from our table | Query `availableShutterSpeeds()` on connect, validate before shooting, substitute nearest |
| 30s exposures need long idle timeout | Timeout = shutter seconds + 30s buffer in RoccCameraHardware |
| Camera dies mid-shoot | Partial completion tracking already built; retry-remaining already wired |
| Type name collision (ShutterSpeed) | Module-qualify as `Rocc.ShutterSpeed` in mapping file |
| Silent shutter speed failures | Verify-retry loop already built (3 attempts, 300ms backoff, os_log diagnostics) |

## Integration Test Plan (Physical Camera)

Requires: Sony Alpha camera with WiFi (A7 series, A6xxx, or RX100), set to Manual mode, on tripod.

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 1 | Discovery + connect | Enable camera WiFi, join from iPhone, open app, tap Connect Camera | Camera appears in list, connects, shows model name |
| 2 | Mode validation | Connect with camera in Aperture Priority | App shows "Set Camera to Manual Mode" with dial icon and "Check Again" button |
| 3 | Mode re-check | From wrong mode screen, switch camera dial to M, tap "Check Again" | Transitions to connected, auto-dismisses |
| 4 | Simple bracket (1 set, 3 frames) | Shadow 1/125, Highlight 1/500, 3 frames, 1 EV | Confirmation shows 1 set, 3 exposures. Shoot completes. 3 photos on card. Haptic per capture. |
| 5 | Multi-set bracket (3 sets, 15 frames) | Shadow 1/4, Highlight 1/1000, 5 frames, 1 EV | Progress shows per-frame status labels cycling through setting/verifying/capturing. 15 photos on card. |
| 6 | Shutter verify retry | Connect to camera known to occasionally ignore speed changes | os_log shows verify mismatch warnings, retries succeed, shoot completes |
| 7 | WiFi disconnect mid-shoot | Start 3-set bracket, toggle camera WiFi off at set 2 | Progress shows paused. Reconnect WiFi. Shoot resumes and completes. |
| 8 | Cancel mid-shoot | Start 3-set bracket, tap Cancel at set 2 | Shooting stops. Returns to idle. |
| 9 | Unavailable speed | Configure bracket including 1/8000 on camera that maxes at 1/4000 | Confirmation warns about substitution. Shoot uses nearest available speed. |
| 10 | Long exposure | Shadow 4s, Highlight 1/30, 3 frames, 2 EV | Shoot waits for each long exposure to complete. No timeout. |
| 11 | App background during shoot | Start shoot, press home button | Shoot continues via background task. Return to app shows progress. |
| 12 | Retry remaining after failure | Start 3-set bracket, force disconnect at set 2 frame 3, dismiss | Shows partial. Tap Retry Remaining. Completes remaining frames. |

## Verification

- Phase 1 rocc API validated against cloned source
- All existing 74 tests still pass (Speeds, Calculator, SonyCameraTypes, CameraConnectionService, ShootingViewModel)
- New ShutterSpeedMapping tests pass (all 55 speeds map correctly, plus validation function)
- Project builds with no warnings
- All 12 integration test scenarios pass on physical Sony Alpha camera

## Deferred (Post-Integration)

- WiFi reconnection recovery during shooting (detect drop, pause, offer reconnect, auto-resume)
- Tune `perFrameOverheadSeconds` and `retryDelay` with real-world measurements from multiple camera models
- Integration test script for automated real-hardware testing
- Shutter Priority mode support (spec currently requires Manual only)
- Camera presets database (known speed ranges per model)
