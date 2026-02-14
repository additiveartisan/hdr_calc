# HDR Calculator: Web App Spec (SvelteKit)

A modern, minimal HDR exposure bracketing calculator. Single-page SvelteKit web app with PWA support. Clean Apple aesthetic, adaptive light/dark mode.

---

## Core Interaction

No "Calculate" button. Everything is **reactive**: adjust any input and results update instantly.

### Inputs

| Input | Control | Values |
|-------|---------|--------|
| **Shadow speed** | Custom dropdown selector (tap to expand, scroll, tap to confirm) | Full 1/3-stop shutter speed scale: 30s down to 1/8000s |
| **Highlight speed** | Same as above | Same scale |
| **Frames per AEB set** | Segmented control (custom radio group with animated pill) | 3, 5, 7, 9 |
| **EV spacing** | Segmented control | 1, 1.5, 2 stops |

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
- `seconds`: float value for EV calculation
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

The algorithm builds sets iteratively from the bright end, advancing frame-by-frame with `Math.ceil` rounding toward darker exposures.

```
function calculate(shadow_index, highlight_index, frames, spacing):
    // spacing is in EV stops: 1, 1.5, or 2

    bright = min(shadow_index, highlight_index)
    dark   = max(shadow_index, highlight_index)
    range_ev = (dark - bright) / 3

    if range_ev <= 0:
        return { sets: 0, total: 1, message: "Single exposure" }

    step = spacing * 3   // index units per frame (may be fractional)
    coverage = (frames - 1) * spacing

    // Single set covers the range
    if range_ev <= coverage:
        return { sets: [build_set(bright, frames, step)], total: frames }

    // Multiple sets: iterate until last frame exceeds dark index
    sets = []
    set_start = bright
    loop:
        set = build_set(set_start, frames, step)
        sets.append(set)
        if set.last_index > dark: break
        set_start = set.last_index   // next set starts at previous set's last frame

    return { sets, total: len(sets) * frames, range_ev }

function build_set(start, frames, step):
    indices = [start]
    current = start
    for f in 1..frames-1:
        current = ceil(current + step)   // round toward darker
        current = clamp(current, 0, max_index)
        indices.append(current)
    return indices
```

### Rounding Rule

When a computed frame index falls between two entries in the speed table, **round toward the darker (slower) exposure** using `Math.ceil`. This produces slightly more overlap between adjacent frames, which is safer for HDR merging (no tonal gaps). For fractional spacing (e.g. 1.5 EV), rounding is applied cumulatively from each frame's already-rounded position.

### Set Overlap

Adjacent sets share exactly one frame: the last frame of set N becomes the first frame of set N+1. Sets continue until the last frame's index strictly exceeds the dark end, ensuring full coverage with extra safety margin.

**Constraint**: Max 2 EV spacing between frames (enforced by the selector maxing at 2).

---

## Default State

On first load, the app pre-fills a typical real estate interior scenario:

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
| **Maximum range** (30" to 1/8000 = ~18 EV) | Can produce 5+ sets. Results section scrolls vertically. |
| **Range barely exceeds N sets** | An extra set is added even for a fraction of an EV. The outermost frames may extend slightly beyond the metered range, which is fine (extra coverage). |

---

## Test Vectors

The TypeScript implementation must match these exact results. Validated against the shared `test_vectors.json` in the project root.

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

A precision tool with quiet confidence. Single stacked column layout, compact controls, tick-mark rulers for set breakdowns. Everything is restrained and functional.

### Layout (Single Column, All Screen Sizes)

```
┌─────────────────────────────┐
│                             │
│  HDR Calculator ──────────  │  Title with trailing rule line
│                             │
│  Shadows                    │
│  ┌───────────────────────┐  │
│  │  1/4              ▾   │  │  Compact dropdown
│  └───────────────────────┘  │
│                             │
│  Highlights                 │
│  ┌───────────────────────┐  │
│  │  1/1000           ▾   │  │
│  └───────────────────────┘  │
│                             │
│  AEB Frames                 │
│  ┌───┬───┬───┬───┐         │
│  │ 3 │ 5 │ 7 │ 9 │         │  Compact segmented control
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

Max width: 480px centered on desktop.

### Typography

- **Font**: Outfit (Google Fonts), geometric sans-serif. Weights: 400, 500, 600.
- App title: 600 weight, 20px, with trailing rule line
- Section labels: 500 weight, 13px, uppercase tracking, muted color
- Shutter speed values in dropdowns: 500 weight, 15px
- Scene range number: 600 weight, 20px, with trailing rule line (matches title)
- Set breakdown tick labels: 400 weight, 11px (center speed: 600 weight, 13px, accent color)

### Color Palette

```
Light Mode:
  --bg:           #FFFFFF
  --card:         #F5F5F4    (warm gray)
  --card-border:  #E8E8E6
  --text:         #1C1C1E
  --text-muted:   #8E8E93
  --accent:       #D4881E    (warm amber)
  --accent-soft:  #D4881E1A  (10% amber for backgrounds)

Dark Mode:
  --bg:           #000000    (true black for OLED)
  --card:         #1C1C1E
  --card-border:  #2C2C2E
  --text:         #F5F5F0
  --text-muted:   #8E8E93
  --accent:       #E9A84C    (slightly brighter amber for dark bg)
  --accent-soft:  #E9A84C1A
```

### Set Breakdown: Tick-Mark Rulers

Each set is displayed as a horizontal line with evenly-spaced tick marks (like the iOS Camera app exposure dial):

- Horizontal track line in muted color
- Tick marks at each frame position, evenly distributed
- Speed labels below each tick
- **Center speed** has a taller, bolder tick in accent color with larger, bold label
- Set header shows colored dot + "Set N" label

### Controls Detail

**Shutter Speed Pickers:**
- Compact dropdown styled as a card (8px 12px padding, 8px border radius)
- Shows current value when collapsed with chevron indicator
- Tap to expand into a scrollable dropdown list (max-height 280px)
- Click to select, click outside or Escape to dismiss
- Full 1/3-stop scale from 30" to 1/8000

**Segmented Controls:**
- Custom radio group with animated pill indicator
- Pill position measured from actual button DOM elements for pixel-perfect fit
- Pill inset 2px from button edges
- Selected state: accent color fill, white text
- Unselected: transparent, muted text
- Smooth 300ms ease-out animation (no spring/bounce overshoot)

### Heading Rule Lines

Both "HDR Calculator" and the EV range stat display a thin horizontal rule extending from the text to the right edge of the container. Implemented with `::after` pseudo-element (flex + 1px line in card-border color).

### Animations & Transitions

- Segmented control pill: 300ms cubic-bezier(0.25, 1, 0.5, 1) slide
- All animations respect `prefers-reduced-motion`

### Spacing System

Base unit: 8px. All spacing is multiples of 8.

- Page padding: 24px (mobile), 48px (desktop)
- Dropdown padding: 8px 12px
- Card gap: 12px
- Section gap: 24px
- Dropdown border radius: 8px
- Segmented control radius: 8px

---

## Accessibility

### Color Contrast
- All text meets WCAG AA (4.5:1 for body, 3:1 for large text)
- Accent amber on white card: 3.2:1 (passes AA for large text/UI components). Pair with dark text for small body copy.

### Screen Readers
- All segmented controls use proper `aria-label` and `aria-checked` states
- Speed pickers use `aria-expanded`, `aria-activedescendant` when open

### Keyboard Navigation
- Tab order: Shadow picker, Highlight picker, AEB Frames, EV Spacing, then results
- Segmented controls navigable with arrow keys
- Shutter speed picker navigable with arrow keys when focused
- Escape closes an open picker

### Reduced Motion
- All animations respect `prefers-reduced-motion`
- When enabled: instant transitions, no animations

---

## Platform Details

- **Framework**: SvelteKit
- **Single page**: no routing needed
- **PWA**: manifest + service worker for offline/Add to Home Screen
- **Deployment**: Vercel or Cloudflare Pages
- **Responsive**: works on phone (320px+) through desktop
- **Minimal bundle**: calculator logic is tiny, Outfit font loaded from Google Fonts

---

## What's NOT In Scope (MVP)

- Camera presets database
- Calculation history/saving
- User accounts
- Camera integration
- Export/share functionality
- Tutorials or onboarding

---

## Project Structure

```
~/.local/src/hdr_calculator/
  test_vectors.json              # Shared parity contract with iOS
  web/
    src/
      lib/
        calculator.ts            # Core algorithm
        calculator.test.ts       # Tests using test_vectors.json
        speeds.ts                # Shutter speed lookup table (55 entries)
        speeds.test.ts           # Speed table tests
        components/
          SegmentedControl.svelte  # Animated pill radio group
          SpeedPicker.svelte       # Dropdown speed selector
      routes/
        +page.svelte             # Single page app (reactive)
        +layout.svelte           # Theme provider, font loading, PWA meta
      app.css                    # CSS variables, design tokens, base styles
      service-worker.ts          # Offline caching
    static/
      manifest.json              # PWA manifest
      favicon.svg                # Camera icon
    vite.config.ts               # Vitest integration
    svelte.config.js
    package.json
```
