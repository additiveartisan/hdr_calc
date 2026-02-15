# Sony Camera Control Integration for HDR Calc iOS

## Context

HDR Calc iOS is a complete, working bracket calculator with camera metering via AVCaptureSession. The user wants to add the ability to connect to a Sony camera over WiFi and automatically fire all bracket sets, eliminating the need to manually adjust shutter speed between sets on the camera body.

**Why rocc?** The official Sony Camera Remote SDK is C++ only (Windows/macOS/Linux desktop). rocc is an MIT-licensed Swift framework that reverse-engineers Sony's PTP/IP protocol, providing shutter speed control and shutter release over WiFi. It's the only viable path for iOS.

## Workflow (User Perspective)

1. **Connect**: Tap "Connect Camera" in inputs section. App discovers Sony cameras on WiFi via SSDP. Tap camera name to connect. App validates camera is in Manual or Shutter Priority mode and queries available shutter speeds.
2. **Meter + Configure**: Meter scene shadows/highlights (existing), set AEB frames and EV spacing (existing). Changing settings while connected updates the bracket plan live.
3. **Review + Confirm**: Tap "Shoot All Sets" button (appears in results when camera connected). Confirmation sheet shows: "3 sets, 15 exposures. Longest exposure: 4s. Estimated time: ~12s. Proceed?" Any speeds not available on the camera are flagged with nearest substitutes.
4. **Shoot**: App begins bracket sequence. Progress overlay shows current set/frame/speed with a progress bar. Haptic tap on each successful capture. If disconnected, auto-pauses and shows reconnect prompt. If app is backgrounded, continues via background task.
5. **Done**: Progress shows "Complete: 15 of 15 exposures captured". If partial failure: "Stopped at Set 2, Frame 3. 8 of 15 exposures captured. [Retry Remaining] [Dismiss]". Dismiss returns to calculator.

## Architecture

| Layer | File | Role |
|-------|------|------|
| Protocol | `SonyCameraProtocol.swift` | Abstracts camera ops for testability |
| Discovery | `SonyCameraDiscovery.swift` | SSDP discovery + connection lifecycle |
| Camera Control | `SonyCameraControl.swift` | Shutter speed + capture commands on a connected camera |
| Bracket Runner | `BracketRunner.swift` | Sequences set speed + fire across all sets |
| WiFi Monitor | `WiFiMonitor.swift` | NWPathMonitor SSID tracking, auto-pause on network change |
| Connect UI | `CameraConnectView.swift` | Discovery list + connection sheet |
| Progress UI | `ShootProgressView.swift` | Full-screen shooting progress overlay |
| Confirm UI | `ShootConfirmView.swift` | Pre-shoot review with speed validation |
| Speed Mapping | `ShutterSpeedMapping.swift` | Our ShutterSpeed to rocc ShutterSpeed |

**Design note**: SonyCameraService is split into Discovery and Control to separate concerns. Discovery manages the `CameraDiscoverer` lifecycle and connection state. Control wraps the connected camera's command execution and event monitoring.

## Implementation Phases

### Phase 0: Validate rocc API

Before writing any code, clone rocc locally and confirm:
- `ShutterSpeed` type has `numerator`/`denominator` properties (or document actual API)
- `performFunction(Shutter.Speed.set, payload:)` accepts a `ShutterSpeed` payload
- `performFunction(StillCapture.take, payload:)` exists and returns on capture complete
- `CameraEvent.shutterSpeed` exposes available speed list
- `isFunctionAvailable(Shutter.Speed.set)` works for mode detection

If rocc's ShutterSpeed uses a different representation (string, enum, etc.), revise Phase 2 mapping approach before proceeding.

### Phase 1: SPM Dependency + Protocol Foundation

| File | Action | Detail |
|------|--------|--------|
| `project.pbxproj` | Edit | Add rocc SPM: `https://github.com/simonmitchell/rocc.git` from 2.0.0 |
| `SonyCameraProtocol.swift` | Create | `RemoteCamera` protocol (see below) |

Protocol surface:

```
protocol RemoteCamera: AnyObject {
    var isConnected: Bool { get }
    func setShutterSpeed(_ speed: RoccShutterSpeed) async throws
    func captureStill() async throws
    func currentStatus() async throws -> RemoteCameraStatus
    func availableShutterSpeeds() async throws -> [RoccShutterSpeed]
    func shootingMode() async throws -> ShootingMode
}
```

`availableShutterSpeeds()` enables pre-shoot validation. `shootingMode()` enables M/S mode checking.

### Phase 2: Shutter Speed Mapping (TDD)

| File | Action | Detail |
|------|--------|--------|
| `ShutterSpeedMappingTests.swift` | Create | RED: Test all 55 speeds map to correct numerator/denominator |
| `ShutterSpeedMapping.swift` | Create | GREEN: Extension on ShutterSpeed with `.roccShutterSpeed` computed property |

Mapping logic:
- `"1/1000"` parses to numerator=1, denominator=1000
- `"2\""` parses to numerator=2, denominator=1
- `"0.3\""` parses to numerator=3, denominator=10
- Labels are used (not seconds) because they match Sony's standard values exactly

Additional function:

```
func validateSpeeds(
    sets: [[ShutterSpeed]],
    available: [RoccShutterSpeed]
) -> SpeedValidationResult
```

Returns which speeds are available, which need substitution, and the nearest available alternative for each unavailable speed. This powers the confirmation UI.

### Phase 3: BracketRunner (TDD)

| File | Action | Detail |
|------|--------|--------|
| `BracketRunnerTests.swift` | Create | RED: MockRemoteCamera, comprehensive test coverage (see below) |
| `BracketRunner.swift` | Create | GREEN: Actor that iterates sets, calls setSpeed + capture, emits AsyncStream progress |

Key behaviors:
- Iterates `[[ShutterSpeed]]` from CalculationResult.sets
- For each frame: set speed, wait for speed-change confirmation event, capture, wait for idle
- Progress via `AsyncStream<BracketProgress>` (set, frame, speed, phase)
- Cancellation via `cancel()`, pause/resume for disconnect recovery
- Retry with backoff for `busy` errors only (3 attempts)
- Idle timeout = shutter speed duration + 10s buffer (handles 30s exposures)
- Tracks completion position for partial failure reporting and resume
- Haptic feedback (UIImpactFeedbackGenerator) on each successful capture

BracketProgress includes:
- `completedFrames: Int` (total across all sets so far)
- `resumePosition: (set: Int, frame: Int)?` (for retry-remaining)

TDD sequence and required tests:

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | `testSingleSetShoots3Frames` | Happy path, correct total |
| 2 | `testSpeedsAreSetInOrder` | Frame ordering within set |
| 3 | `testMultipleSetsShootsAllFrames` | Outer loop over sets |
| 4 | `testProgressReportsAllPhases` | AsyncStream emits settingSpeed, capturing, waitingForIdle, complete |
| 5 | `testWaitForIdleImmediateReturn` | Camera returns idle instantly |
| 6 | `testWaitForIdleSequence` | Camera goes capturing, saving, then idle |
| 7 | `testWaitForIdleTimeout` | Camera never returns idle, throws timeout |
| 8 | `testWaitForIdleErrorStatus` | Camera returns error during wait |
| 9 | `testCancelStopsShooting` | isCancelled checked at loop boundaries |
| 10 | `testPauseAndResume` | Pause mid-shoot, resume, verify all frames complete |
| 11 | `testSetSpeedFailurePropagates` | Non-retryable error stops run |
| 12 | `testBusyRetriesAndSucceeds` | Mock fails twice with busy, succeeds third time |
| 13 | `testBusyRetriesExhausted` | Mock fails 3x with busy, propagates error |
| 14 | `testEmptySetsCompletesImmediately` | Edge case, 0 total |
| 15 | `testPartialCompletionTracksPosition` | Fail at set 2 frame 3, verify completedFrames=8 and resumePosition |
| 16 | `testResumeFromPosition` | Start from set 2 frame 3, verify only remaining frames fire |

MockRemoteCamera supports:
- Per-method call counting
- Configurable failure sequences (fail N times then succeed)
- Configurable status sequences (capturing, saving, idle)
- Settable `isConnected` flag

### Phase 4: Camera Service (rocc wrapper, split into two files)

| File | Action | Detail |
|------|--------|--------|
| `SonyCameraDiscovery.swift` | Create | @Observable class managing discovery + connection lifecycle |
| `SonyCameraControl.swift` | Create | Conforms to RemoteCamera protocol, wraps connected camera commands |
| `WiFiMonitor.swift` | Create | NWPathMonitor wrapper for SSID change detection |

**SonyCameraDiscovery** responsibilities:
- `CameraDiscoverer` for SSDP WiFi discovery (delegate-based)
- `connect(to:)` / `disconnect()` lifecycle
- Observable state: `connectionState`, `discoveredCameras`, `cameraName`
- On successful connection, creates `SonyCameraControl` instance
- Stores camera WiFi SSID at connection time for WiFiMonitor comparison

**SonyCameraControl** responsibilities (conforms to `RemoteCamera`):
- `performFunction(Shutter.Speed.set, payload:)` bridged to async via `withCheckedThrowingContinuation`
- `performFunction(StillCapture.take, payload:)` bridged to async
- `CameraEventNotifier` to track camera status (idle/capturing/saving)
- `DeviceConnectivityNotifier` for disconnect/reconnect callbacks
- `availableShutterSpeeds()` from CameraEvent's shutter speed available list
- `shootingMode()` from CameraEvent's current mode
- Speed-change confirmation: after `setShutterSpeed()`, poll events until reported speed matches target (replaces fixed 200ms delay)

**WiFiMonitor** responsibilities:
- Uses `NWPathMonitor` to observe network changes
- Compares current WiFi SSID against stored camera SSID
- Calls `onSSIDChanged` callback when network switches away from camera WiFi
- BracketRunner pauses immediately on SSID change, resumes when SSID returns
- Requires `Access WiFi Information` entitlement and `CNCopyCurrentNetworkInfo` or `NEHotspotNetwork.fetchCurrent()`

### Phase 5: UI Integration

| File | Action | Detail |
|------|--------|--------|
| `CameraConnectView.swift` | Create | Sheet with discovery list, connection progress, mode validation, error states |
| `ShootConfirmView.swift` | Create | Pre-shoot confirmation: set count, frame count, estimated time, speed warnings |
| `ShootProgressView.swift` | Create | Full-screen overlay: current set/frame, speed label, progress bar, cancel, pause state |
| `ShootingViewModel.swift` | Create | Shooting state isolated from calculator (see below) |
| `ContentView.swift` | Edit | Add "Connect Camera" button to inputs, "Shoot All Sets" button to results, sheet presentations |
| `HDRCalcApp.swift` | Edit | Create SonyCameraDiscovery, inject via `@Environment` |
| `project.pbxproj` | Edit | Add Info.plist keys (see below) |

**ShootingViewModel** (separate from CalculatorViewModel):
- Owns `BracketRunner` instance and `WiFiMonitor`
- Published state: `currentProgress`, `isShooting`, `isPaused`, `completionResult`
- `startShooting(sets:camera:)` creates runner, begins background task, wires WiFi monitor
- `cancelShooting()`, `retryRemaining()`
- Manages `UIApplication.shared.beginBackgroundTask` for background execution

**CameraConnectView** states:
1. **Disconnected**: "Connect your iPhone to your Sony camera's WiFi" + Search button
2. **Discovering**: Spinner + list of found cameras as they appear
3. **Connecting**: "Connecting to [camera name]..."
4. **Mode check**: If camera not in M/S mode: "Switch your camera to Manual (M) or Shutter Priority (S) mode to enable remote control"
5. **Connected**: Checkmark + camera name + "Done" button
6. **Error**: Error message + Retry button

**ShootConfirmView** content:
- "Ready to Shoot" header
- Set count, total exposures, estimated time
- List of any unavailable speeds with substitutions: "1/6400 not available on this camera, using 1/5000 instead"
- "Shoot" and "Cancel" buttons

**ShootProgressView** states:
- **Shooting**: Set N of M, Frame N of M, speed label, progress bar, pulsing camera icon, Cancel button
- **Paused (disconnect)**: Pause icon, "Camera disconnected. Reconnect WiFi to resume." Resume automatically on reconnect.
- **Paused (WiFi switch)**: "iPhone switched WiFi networks. Reconnect to [camera SSID] to resume."
- **Complete**: Checkmark, "15 of 15 exposures captured", Dismiss button
- **Partial failure**: Warning icon, "Stopped at Set 2, Frame 3. 8 of 15 captured.", [Retry Remaining] [Dismiss]

**Info.plist keys** (added as build settings in project.pbxproj):
- `NSLocalNetworkUsageDescription`: "HDR Calc discovers Sony cameras on your WiFi network to remotely control exposure bracketing."
- `NSBonjourServices`: `["_ssdp._udp"]` (for SSDP multicast discovery)
- `com.apple.developer.networking.wifi-info` entitlement (for SSID monitoring)

**Background task handling**:
- `UIApplication.shared.beginBackgroundTask` called when shooting starts
- `endBackgroundTask` called on completion, cancellation, or failure
- If background time expires before completion: pause runner, notify user on next foreground that shoot was interrupted, offer resume

**Haptic feedback**:
- `UIImpactFeedbackGenerator(style: .light)` fires on each successful capture
- `UINotificationFeedbackGenerator.notificationOccurred(.success)` on session complete
- `UINotificationFeedbackGenerator.notificationOccurred(.error)` on failure
- Respects system haptic settings automatically

### Phase 6: Build + Test

- `RunAllTests`: All existing 22 tests + new mapping/runner tests pass
- `BuildProject`: Clean build with no warnings
- Manual integration test with physical Sony Alpha camera (see test plan below)

## Files Modified

| File | Change |
|------|--------|
| `HDRCalc/ContentView.swift` | Add "Connect Camera" button, "Shoot All Sets" button, sheet presentations |
| `HDRCalc/HDRCalcApp.swift` | Create SonyCameraDiscovery, inject via environment |
| `project.pbxproj` | SPM dependency, new file references, Info.plist keys, WiFi entitlement |

## New Files (9 source + 2 test)

| File | Target |
|------|--------|
| `HDRCalc/SonyCameraProtocol.swift` | App |
| `HDRCalc/SonyCameraDiscovery.swift` | App |
| `HDRCalc/SonyCameraControl.swift` | App |
| `HDRCalc/ShutterSpeedMapping.swift` | App |
| `HDRCalc/BracketRunner.swift` | App |
| `HDRCalc/WiFiMonitor.swift` | App |
| `HDRCalc/ShootingViewModel.swift` | App |
| `HDRCalc/CameraConnectView.swift` | App |
| `HDRCalc/ShootConfirmView.swift` | App |
| `HDRCalc/ShootProgressView.swift` | App |
| `HDRCalcTests/ShutterSpeedMappingTests.swift` | Tests |
| `HDRCalcTests/BracketRunnerTests.swift` | Tests |

## Existing Files Referenced (no changes)

- `Speeds.swift` - ShutterSpeed struct with index/label/seconds/ev (extended in ShutterSpeedMapping.swift)
- `Calculator.swift` - CalculationResult.sets provides `[[ShutterSpeed]]` input to BracketRunner
- `CameraService.swift` - Existing AVCaptureSession metering (unchanged, separate from Sony control)

## Risks + Mitigations

| Risk | Mitigation |
|------|------------|
| rocc's ShutterSpeed type unverified | Phase 0: clone repo, inspect type before building mapping layer |
| rocc last updated 2020 | PTP/IP protocol is stable; fork if needed for new models |
| Per-shot WiFi latency (~300ms) | Acceptable for tripod HDR work; 15 frames takes ~8-10s vs manual |
| Camera must be in M/S mode | Validate mode at connection time, show clear guidance to switch modes |
| iOS switches away from camera WiFi | WiFiMonitor tracks SSID via NWPathMonitor, auto-pauses on network change |
| App backgrounded during shoot | beginBackgroundTask for extended execution; pause and notify if time expires |
| Camera shutter speeds differ from our table | Query availableShutterSpeeds on connect, validate before shooting, substitute nearest |
| 30s exposures need long idle timeout | Timeout = shutter seconds + 10s buffer |
| Camera dies mid-shoot | Partial completion tracking; show exactly what was captured; offer retry-remaining |
| Type name collision (ShutterSpeed) | Module-qualify as `Rocc.ShutterSpeed` in mapping file |
| Accidental shoot tap | Confirmation sheet with full bracket plan review before firing |

## Integration Test Plan (Physical Camera)

Requires: Sony Alpha camera with WiFi (A7 series, A6xxx, or RX100), set to Manual mode, on tripod.

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 1 | Discovery + connect | Enable camera WiFi, join from iPhone, open app, tap Connect Camera | Camera appears in list, connects, shows model name |
| 2 | Mode validation | Connect with camera in Aperture Priority | App shows "Switch to M or S mode" message |
| 3 | Simple bracket (1 set, 3 frames) | Shadow 1/125, Highlight 1/500, 3 frames, 1 EV | Confirmation shows 1 set, 3 exposures. Shoot completes. 3 photos on card. |
| 4 | Multi-set bracket (3 sets, 15 frames) | Shadow 1/4, Highlight 1/1000, 5 frames, 1 EV | Confirmation shows 3 sets, 15 exposures. Progress updates per frame. Haptic per capture. 15 photos on card. |
| 5 | WiFi disconnect mid-shoot | Start 3-set bracket, toggle camera WiFi off at set 2 | Progress shows paused. Reconnect WiFi. Shoot resumes and completes. |
| 6 | Cancel mid-shoot | Start 3-set bracket, tap Cancel at set 2 | Shooting stops. Shows partial completion count. |
| 7 | Unavailable speed | Configure bracket including 1/8000 on camera that maxes at 1/4000 | Confirmation warns about substitution. Shoot uses nearest available speed. |
| 8 | Long exposure | Shadow 4s, Highlight 1/30, 3 frames, 2 EV | Shoot waits for each long exposure to complete. No timeout. |
| 9 | App background during shoot | Start shoot, press home button | Shoot continues via background task. Return to app shows progress. |
| 10 | Retry remaining after failure | Start 3-set bracket, force disconnect at set 2 frame 3, dismiss | Shows partial. Tap Retry Remaining. Completes remaining frames. |

## Verification

- Phase 0 rocc API validated against cloned source
- All existing 22 tests still pass (Speeds + Calculator)
- New ShutterSpeedMapping tests pass (all 55 speeds map correctly, plus validation function)
- New BracketRunner tests pass (16 tests covering sequencing, progress, idle-wait, cancel, pause/resume, retry, partial completion, resume-from-position)
- Project builds with no warnings
- All 10 integration test scenarios pass on physical Sony Alpha camera
