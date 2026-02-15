# Sony Camera Control Integration for HDR Calc iOS

## Context

HDR Calc iOS is a complete, working bracket calculator with camera metering via AVCaptureSession. The user wants to add the ability to connect to a Sony camera over WiFi and automatically fire all bracket sets, eliminating the need to manually adjust shutter speed between sets on the camera body.

**Why rocc?** The official Sony Camera Remote SDK is C++ only (Windows/macOS/Linux desktop). rocc is an MIT-licensed Swift framework that reverse-engineers Sony's PTP/IP protocol, providing shutter speed control and shutter release over WiFi. It's the only viable path for iOS.

## Workflow (User Perspective)

1. **Connect**: Tap "Connect Camera" in inputs section. App discovers Sony cameras on WiFi via SSDP. Tap camera name to connect.
2. **Meter + Configure**: Meter scene shadows/highlights (existing), set AEB frames and EV spacing (existing).
3. **Shoot**: Tap "Shoot All Sets" button (appears in results when camera connected). App iterates all bracket sets: sets shutter speed on camera, fires shutter, waits for idle, advances. Progress overlay shows current set/frame/speed.
4. **Done**: Progress shows "Complete: N exposures captured". Dismiss and review on camera.

## Architecture

Three new layers, each with clear responsibility:

| Layer | File | Role |
|-------|------|------|
| Protocol | `SonyCameraProtocol.swift` | Abstracts camera ops for testability |
| Camera Service | `SonyCameraService.swift` | Wraps rocc discovery/connection/commands |
| Bracket Runner | `BracketRunner.swift` | Sequences set speed + fire across all sets |
| Connect UI | `CameraConnectView.swift` | Discovery list + connection sheet |
| Progress UI | `ShootProgressView.swift` | Full-screen shooting progress overlay |
| Speed Mapping | `ShutterSpeedMapping.swift` | Our ShutterSpeed to rocc ShutterSpeed |

## Implementation Phases

### Phase 1: SPM Dependency + Protocol Foundation

| File | Action | Detail |
|------|--------|--------|
| `project.pbxproj` | Edit | Add rocc SPM: `https://github.com/simonmitchell/rocc.git` from 2.0.0 |
| `SonyCameraProtocol.swift` | Create | `RemoteCamera` protocol with `setShutterSpeed()`, `captureStill()`, `currentStatus()` using async/await |

The protocol decouples BracketRunner from rocc, enabling mock-based testing.

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

### Phase 3: BracketRunner (TDD)

| File | Action | Detail |
|------|--------|--------|
| `BracketRunnerTests.swift` | Create | RED: MockRemoteCamera, test sequencing/progress/cancel/retry/errors |
| `BracketRunner.swift` | Create | GREEN: Actor that iterates sets, calls setSpeed + capture, emits AsyncStream progress |

Key behaviors:
- Iterates `[[ShutterSpeed]]` from CalculationResult.sets
- For each frame: set speed, 200ms settle, capture, wait for idle
- Progress via `AsyncStream<BracketProgress>` (set, frame, speed, phase)
- Cancellation via `cancel()`, pause/resume for disconnect recovery
- Retry with backoff for `busy` errors only (3 attempts)
- Idle timeout = shutter speed duration + 10s buffer (handles 30s exposures)

TDD sequence: single set > ordering > multiple sets > progress > cancel > errors > retry > empty sets

### Phase 4: SonyCameraService (rocc wrapper)

| File | Action | Detail |
|------|--------|--------|
| `SonyCameraService.swift` | Create | @Observable class conforming to RemoteCamera protocol |

Responsibilities:
- `CameraDiscoverer` for SSDP WiFi discovery (delegate-based)
- `camera.connect()` / `disconnect()` lifecycle
- `performFunction(Shutter.Speed.set, payload:)` bridged to async via `withCheckedThrowingContinuation`
- `performFunction(StillCapture.take, payload:)` bridged to async
- `CameraEventNotifier` to track camera status (idle/capturing/saving)
- `DeviceConnectivityNotifier` for disconnect/reconnect callbacks
- Observable state: `connectionState`, `discoveredCameras`, `cameraName`

### Phase 5: UI Integration

| File | Action | Detail |
|------|--------|--------|
| `CameraConnectView.swift` | Create | Sheet with discovery list, connection progress, error states |
| `ShootProgressView.swift` | Create | Full-screen overlay: current set/frame, speed label, progress bar, cancel |
| `ContentView.swift` | Edit | Add connection status + "Connect Camera" button to inputs, "Shoot All Sets" button to results, sheet/cover presentations |
| `HDRCalcApp.swift` | Edit | Create SonyCameraService, inject via environment |
| `project.pbxproj` | Edit | Add Info.plist key `NSLocalNetworkUsageDescription` for WiFi camera discovery |

### Phase 6: Build + Test

- `RunAllTests`: All existing tests + new mapping/runner tests pass
- `BuildProject`: Clean build with no warnings
- Manual test with physical Sony camera (required for end-to-end)

## Files Modified

| File | Change |
|------|--------|
| `HDRCalc/ContentView.swift` | Add shooting state to ViewModel, Connect/Shoot buttons, sheet presentations |
| `HDRCalc/HDRCalcApp.swift` | Create and inject SonyCameraService |
| `project.pbxproj` | SPM dependency, new file references, Info.plist keys |

## New Files (6 source + 2 test)

| File | Target |
|------|--------|
| `HDRCalc/SonyCameraProtocol.swift` | App |
| `HDRCalc/SonyCameraService.swift` | App |
| `HDRCalc/ShutterSpeedMapping.swift` | App |
| `HDRCalc/BracketRunner.swift` | App |
| `HDRCalc/CameraConnectView.swift` | App |
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
| rocc last updated 2020 | PTP/IP protocol is stable; fork if needed for new models |
| Per-shot WiFi latency (~300ms) | Acceptable for tripod HDR work; 15 frames takes ~8-10s vs manual |
| Camera must be in M/S mode | Check `isFunctionAvailable(Shutter.Speed.set)` on connect, show message if wrong mode |
| iOS may switch away from camera WiFi | Show reminder to stay on camera WiFi network |
| 30s exposures need long idle timeout | Timeout = shutter seconds + 10s buffer |
| Type name collision (ShutterSpeed) | Module-qualify as `Rocc.ShutterSpeed` in mapping file |

## Verification

- All existing 22 tests still pass (Speeds + Calculator)
- New ShutterSpeedMapping tests pass (all 55 speeds map correctly)
- New BracketRunner tests pass (sequencing, progress, cancel, retry, errors)
- Project builds with no warnings
- End-to-end bracket shooting tested on physical Sony Alpha camera over WiFi
