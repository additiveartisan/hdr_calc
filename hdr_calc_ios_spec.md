# HDR Calc: iOS App Spec (SwiftUI)

A modern, minimal HDR exposure bracketing calculator. Native SwiftUI app. Clean Apple aesthetic, adaptive light/dark mode.

---

## Core Interaction

No "Calculate" button. Everything is **reactive**: adjust any input and results update instantly via SwiftUI state bindings.

### Inputs

| Input | Control | Values |
|-------|---------|--------|
| **Shadow speed** | Native `.wheel` Picker + Meter button | Full 1/3-stop shutter speed scale: 30s down to 1/8000s |
| **Highlight speed** | Same as above | Same scale |
| **Frames per AEB set** | `Picker(.segmented)` | 3, 5, 7, 9 |
| **EV spacing** | `Picker(.segmented)` | 1, 1.5, 2 stops |

### Outputs

- **Scene dynamic range** (in EV stops)
- **Number of bracket sets** needed
- **Total exposures** to capture
- **Per-set breakdown**: horizontal tick-mark ruler for each set with center speed highlighted

---

## Shutter Speed Data Model

Shutter speeds are stored as an **indexed lookup table** of nominal photographic values, not computed from EV math. Cameras display nominal values (e.g. 1/125 instead of the theoretical 1/128), so the app must match what photographers see on their cameras.

Each entry in the table has:
- `index`: integer position (0 = fastest, ascending = slower)
- `label`: display string as shown on cameras (e.g. "1/125", "1/4", `2"`, `30"`)
- `seconds`: Double value for EV calculation
- `ev`: precomputed EV value = log2(1 / seconds)

The distance between adjacent entries is always 1/3 EV stop.

### Full 1/3-Stop Scale (55 values)

```
1/8000, 1/6400, 1/5000, 1/4000, 1/3200, 1/2500, 1/2000, 1/1600,
1/1250, 1/1000, 1/800,  1/640,  1/500,  1/400,  1/320,  1/250,
1/200,  1/160,  1/125,  1/100,  1/80,   1/60,   1/50,   1/40,
1/30,   1/25,   1/20,   1/15,   1/13,   1/10,   1/8,    1/6,
1/5,    1/4,    0.3",   0.4",   1/2,    0.6",   0.8",   1",
1.3",   1.6",   2",     2.5",   3.2",   4",     5",     6",
8",     10",    13",    15",    20",    25",    30"
```

Note: 0.5 seconds is labelled "1/2" (matching common photographic notation used in test vectors).

EV difference between two speeds = `|index_a - index_b| / 3` (since each index step is 1/3 stop).

---

## The Algorithm

### Iterative Set-Building

The algorithm builds sets iteratively from the bright end, advancing frame-by-frame with ceiling rounding toward darker exposures.

```swift
func calculate(shadowIndex: Int, highlightIndex: Int, frames: Int, spacing: Double) -> CalculationResult {
    let bright = min(shadowIndex, highlightIndex)
    let dark   = max(shadowIndex, highlightIndex)
    let rangeEV = Double(dark - bright) / 3.0

    if rangeEV <= 0 {
        return CalculationResult(rangeEV: 0, sets: [], totalExposures: 1)
    }

    let step = spacing * 3.0   // index units per frame (may be fractional)
    let coverage = Double(frames - 1) * spacing

    // Single set covers the range
    if rangeEV <= coverage {
        let set = buildSet(start: bright, frames: frames, step: step)
        return CalculationResult(rangeEV: rangeEV, sets: [set], totalExposures: frames)
    }

    // Multiple sets: iterate until last frame exceeds dark index
    var sets: [[ShutterSpeed]] = []
    var setStart = bright
    for _ in 0..<50 {  // safety limit
        let set = buildSet(start: setStart, frames: frames, step: step)
        sets.append(set)
        let lastIndex = set.last!.index
        if lastIndex > dark { break }
        setStart = lastIndex  // next set starts at previous set's last frame
    }

    return CalculationResult(rangeEV: rangeEV, sets: sets, totalExposures: sets.count * frames)
}

func buildSet(start: Int, frames: Int, step: Double) -> [ShutterSpeed] {
    var indices = [start]
    var current = Double(start)
    for _ in 1..<frames {
        current = (current + step).rounded(.up)  // ceil toward darker
        let clamped = max(0, min(Int(current), speeds.count - 1))
        indices.append(clamped)
        current = Double(clamped)
    }
    return indices.map { speeds[$0] }
}
```

### Rounding Rule

When a computed frame index falls between two entries in the speed table, **round toward the darker (slower) exposure** using `.rounded(.up)` (ceiling). This produces slightly more overlap between adjacent frames, which is safer for HDR merging (no tonal gaps). For fractional spacing (e.g. 1.5 EV), rounding is applied cumulatively from each frame's already-rounded position.

### Set Overlap

Adjacent sets share exactly one frame: the last frame of set N becomes the first frame of set N+1. Sets continue until the last frame's index strictly exceeds the dark end, ensuring full coverage with extra safety margin.

**Constraint**: Max 2 EV spacing between frames (enforced by the selector maxing at 2).

---

## Default State

On first launch, the app pre-fills a typical real estate interior scenario:

| Input | Default |
|-------|---------|
| Shadow speed | 1/4 |
| Highlight speed | 1/1000 |
| AEB Frames | 5 |
| EV Spacing | 1 |

This immediately shows a meaningful result (8 EV range, 3 sets, 15 exposures) so the user sees how the tool works without any interaction.

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| **Shadow = Highlight** (0 EV range) | Show "0 EV, single exposure needed. No bracketing required." |
| **Shadow brighter than highlight** (inverted) | Swap silently. The algorithm uses min/max, so input order doesn't matter. Labels always read "Shadows" and "Highlights" regardless. |
| **Range fits in one set** | Show 1 set. |
| **Maximum range** (30" to 1/8000 = ~18 EV) | Can produce 5+ sets. Results section scrolls vertically via ScrollView. |
| **Range barely exceeds N sets** | An extra set is added even for a fraction of an EV. The outermost frames may extend slightly beyond the metered range, which is fine (extra coverage). |

---

## Test Vectors

The Swift implementation must match these exact results. Validated against the shared `test_vectors.json` in the project root.

### Vector 1: Typical real estate interior
```
Input:  shadow=1/4, highlight=1/1000, frames=5, spacing=1
Range:  8 EV
Sets:   3
Total:  15 exposures
Set 1:  1/1000, 1/500, 1/250, 1/125, 1/60
Set 2:  1/60,   1/30,  1/15,  1/8,   1/4
Set 3:  1/4,    1/2,   1",    2",    4"
```

### Vector 2: Mild contrast (single set)
```
Input:  shadow=1/30, highlight=1/250, frames=5, spacing=1
Range:  3 EV
Sets:   1
Total:  5 exposures
Set 1:  1/250, 1/125, 1/60, 1/30, 1/15
```

### Vector 3: Extreme range, wide spacing
```
Input:  shadow=2", highlight=1/4000, frames=3, spacing=2
Range:  ~13 EV
Sets:   4
Total:  12 exposures
Set 1:  1/4000, 1/1000, 1/250
Set 2:  1/250,  1/60,   1/15
Set 3:  1/15,   1/4,    1"
Set 4:  1",     4",     15"
```

### Vector 4: Zero range
```
Input:  shadow=1/125, highlight=1/125, frames=any, spacing=any
Range:  0 EV
Sets:   0
Total:  1 exposure
Result: "Single exposure. No bracketing required."
```

### Vector 5: Large frames, small spacing
```
Input:  shadow=1/2, highlight=1/2000, frames=9, spacing=1
Range:  ~10 EV
Sets:   2
Total:  18 exposures
Set 1:  1/2000, 1/1000, 1/500, 1/250, 1/125, 1/60, 1/30, 1/15, 1/8
Set 2:  1/8,    1/4,    1/2,   1",    2",    4",   8",   15",  30"
```

### Vector 6: 1.5 EV spacing
```
Input:  shadow=1/4, highlight=1/2000, frames=5, spacing=1.5
Range:  ~9 EV
Sets:   2
Total:  10 exposures
Set 1:  1/2000, 1/640, 1/200, 1/60,  1/20
Set 2:  1/20,   1/6,   1/2,   1.6",  5"
```

---

## UI/UX Design

### Design Concept: "Photographer's Instrument"

A precision tool that feels native to Apple's ecosystem. Single stacked column layout, native controls, tick-mark rulers for set breakdowns. Everything is restrained and functional.

### Layout (Single Screen, ScrollView)

```
┌─────────────────────────────┐
│                             │
│  HDR Calc ──────────  │  Title with trailing rule line
│                             │
│  Shadows                    │
│  ┌───────────────────────┐  │
│  │  ┃  1/4 sec        ┃  │  │  Native wheel picker
│  └───────────────────────┘  │
│                             │
│  Highlights                 │
│  ┌───────────────────────┐  │
│  │  ┃  1/1000 sec     ┃  │  │
│  └───────────────────────┘  │
│                             │
│  AEB Frames                 │
│  ┌───┬───┬───┬───┐         │
│  │ 3 │ 5 │ 7 │ 9 │         │  Picker(.segmented)
│  └───┴───┴───┴───┘         │
│                             │
│  EV Spacing                 │
│  ┌─────┬─────┬─────┐       │
│  │  1  │ 1.5 │  2  │       │
│  └─────┴─────┴─────┘       │
│                             │
│  8 EV ────────────────────  │  Heading with trailing rule line
│  Scene Dynamic Range        │
│  3 sets · 15 exposures      │
│                             │
│  ● Set 1                    │
│  ├──┼──┼──╋──┼──┤          │  Tick-mark ruler
│  1/1000  1/250  1/60        │  Center speed highlighted
│                             │
│  ● Set 2                    │
│  ├──┼──┼──╋──┼──┤          │
│  1/60  1/15  1/4            │
│                             │
│  ● Set 3                    │
│  ├──┼──┼──╋──┼──┤          │
│  1/4  1"  4"                │
│                             │
└─────────────────────────────┘
```

### iPad Layout

On iPad (regular horizontal size class), use a two-column layout: inputs on the left, results on the right. Wrap in a simple `HStack` with fixed sidebar width (360pt).

### Typography

- **Font**: SF Pro (system), no custom fonts
- App title: `.title3` weight `.semibold`, with trailing rule line
- Section labels: `.caption` weight `.medium`, uppercase, secondary foreground
- Shutter speed values: `.body` weight `.medium`
- Scene range number: `.title3` weight `.semibold`, with trailing rule line (matches title)
- Set breakdown tick labels: `.caption2` (center speed: `.caption` weight `.semibold`, accent color)

### Color Palette

Defined as a SwiftUI `Color` extension using asset catalog:

```swift
// Light appearance
static let cardBackground = Color(red: 0.96, green: 0.96, blue: 0.96)  // #F5F5F4
static let cardBorder = Color(red: 0.91, green: 0.91, blue: 0.90)      // #E8E8E6
static let accent = Color(red: 0.83, green: 0.53, blue: 0.12)          // #D4881E

// Dark appearance (use asset catalog color sets for automatic switching)
// accent becomes #E9A84C
```

Use asset catalog color sets with "Any" and "Dark" appearances for automatic switching.

### Set Breakdown: Tick-Mark Rulers

Each set is displayed as a horizontal line with evenly-spaced tick marks (like the iOS Camera app exposure dial):

- Horizontal track line in muted secondary color
- Tick marks at each frame position, evenly distributed across the width
- Speed labels below each tick
- **Center speed** has a taller, bolder tick in accent color with larger, semibold label
- Set header shows colored dot + "Set N" label
- Implemented as a custom SwiftUI view using `GeometryReader` for positioning

### Controls Detail

**Shutter Speed Pickers:**
- Native `Picker` with `.wheel` style inside a card-styled container
- Each picker shows the full 1/3-stop scale
- Wrapped in a rounded rect card with `cardBackground` fill

**Segmented Controls:**
- Native `Picker(.segmented)` with accent tint via `.tint()`
- Wrapped with a muted label above

### Heading Rule Lines

Both the title and the EV range stat display a thin horizontal rule extending from the text to the right edge. Implemented with an `HStack` containing `Text` + `Rectangle().frame(height: 1)`.

### Animations & Transitions

- Results section: `.animation(.default)` on value changes
- Use `withAnimation {}` wrapping state changes for smooth transitions
- Respect `UIAccessibility.isReduceMotionEnabled` by conditionally applying animations

### Spacing System

- Page padding: 24pt (iPhone), 48pt (iPad)
- Card padding: 16pt
- Card gap: 12pt
- Section gap: 24pt
- Card corner radius: 12pt

---

## Accessibility

### VoiceOver
- Each set group is a grouped accessibility element listing its shutter speeds
- Pickers and segmented controls use native accessibility (automatic with SwiftUI)

### Dynamic Type
- All text scales with Dynamic Type up to AX5
- Tick-mark rulers maintain fixed height (visualization, not text)
- Use `@ScaledMetric` for spacing values that should scale with text

### Reduced Motion
- Check `UIAccessibility.isReduceMotionEnabled`
- When enabled: instant transitions, no animated geometry changes

### Color
- All text meets Apple's recommended contrast ratios
- Accent amber paired with dark text for small body copy

---

## Camera Metering

Live camera metering lets photographers point their iPhone at the scene, tap to meter, and auto-fill a shutter speed picker. This removes the need to manually scroll through the 55-entry wheel picker.

### UX Flow

1. Each shutter speed picker (Shadows, Highlights) has a small button using SF Symbol `camera.metering.spot`, positioned as a trailing accessory on the picker's section label.
2. Tapping the button presents a `.sheet` containing a live camera preview.
3. The user taps on the preview to set the metering point (tap-to-expose). A brief reticle animation marks the tap location.
4. The metered shutter speed is displayed as a label overlaying the bottom of the preview, mapped to the nearest 1/3-stop value from the lookup table.
5. The user taps "Use This Speed" to accept the value and dismiss the sheet.
6. The corresponding wheel picker updates to the metered speed.

### Camera Permission

- Request camera access on first meter button tap (not at app launch).
- If the user denies permission, show an inline message in the sheet explaining how to enable it in Settings, with a button that opens `UIApplication.openSettingsURLString`.
- `NSCameraUsageDescription` in Info.plist: "Used to meter exposure from the scene for shutter speed selection".

### Technical Approach

**Capture pipeline:**
- `AVCaptureSession` with `.photo` preset and `AVCaptureDeviceInput` from the default back camera.
- `AVCaptureVideoPreviewLayer` wrapped in a `UIViewRepresentable` for embedding in SwiftUI.
- Session starts when the sheet appears, stops when it dismisses.

**Exposure reading:**
- Observe `AVCaptureDevice.exposureDuration` (a `CMTime`) via KVO on the capture device.
- Convert with `CMTimeGetSeconds(duration)` and pass to the speed mapping function.
- Update the displayed speed each time the observed value changes (debounced to avoid jitter, e.g. 0.15s throttle).

**Tap-to-meter:**
- Convert tap location to normalized `CGPoint` (0...1 coordinate space).
- Set `device.exposurePointOfInterest` to the tap point.
- Trigger `device.exposureMode = .autoExpose` to re-meter at that point.
- Show a brief reticle animation (scale + fade) at the tap location using a SwiftUI overlay.

**Speed mapping (added to `Speeds.swift`):**
```swift
func nearestSpeed(seconds: Double) -> ShutterSpeed {
    speeds.min(by: { abs($0.seconds - seconds) < abs($1.seconds - seconds) })!
}
```
Finds the entry in the lookup table with minimum absolute distance from the metered value.

### New Files

| File | Responsibility |
|------|---------------|
| `CameraService.swift` | `@Observable` class managing `AVCaptureSession` lifecycle, KVO on `exposureDuration`, and the `nearestSpeed` result. Exposes `meteredSpeed: ShutterSpeed?` for the view to bind. |
| `MeterView.swift` | SwiftUI sheet containing the camera preview (`UIViewRepresentable`), tap gesture overlay, metered speed label, and "Use This Speed" dismiss button. Receives a binding to write the selected speed back to the parent. |

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| **Camera permission denied** | Sheet shows explanation text + "Open Settings" button instead of preview |
| **No back camera** (Simulator) | Meter button is hidden; check `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil` |
| **Exposure still settling** | Speed label updates reactively as the camera converges; no special handling needed |
| **Extremely bright/dark (clipped)** | Nearest-speed mapping still works; the mapped value will be at the edge of the table (1/8000 or 30") |

---

## Platform Details

- **Framework**: SwiftUI
- **Minimum deployment**: iOS 17.0 (for latest SwiftUI features, Observable macro)
- **Architecture**: Single-file `@Observable` view model, no external dependencies
- **App Store**: Photo & Video category
- **App size target**: < 5 MB
- **No external dependencies**: pure SwiftUI + Foundation + AVFoundation (camera metering only)
- **Permissions**: `NSCameraUsageDescription` in Info.plist ("Used to meter exposure from the scene for shutter speed selection")

---

## What's NOT In Scope (MVP)

- Camera presets database
- Calculation history/saving
- User accounts
- Export/share functionality
- Tutorials or onboarding
- iPad-specific features beyond adaptive layout
- Apple Watch / macOS targets

---

## Project Structure

```
~/Library/Mobile Documents/com~apple~CloudDocs/Downloads/hdr_calc/
  test_vectors.json              # Shared parity contract with web
  ios/
    HDRCalc.xcodeproj
    HDRCalc/
      HDRCalcApp.swift               # App entry point
      Calculator.swift               # Core algorithm (iterative set-building)
      Speeds.swift                   # Shutter speed lookup table (55 entries) + nearestSpeed()
      ContentView.swift              # Main UI (single column, tick-mark rulers)
      CameraService.swift            # AVCaptureSession setup, exposure observation, speed mapping
      MeterView.swift                # Camera preview sheet with tap-to-meter and speed display
      Theme.swift                    # Colors, spacing constants
      Assets.xcassets/               # Color sets, app icon
    HDRCalcTests/
      CalculatorTests.swift          # Tests using test_vectors.json
```
