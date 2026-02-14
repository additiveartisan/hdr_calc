# HDR Calculator: App Store Connect Metadata

## App Information

**App Name** (30 chars max):
```
HDR Calculator
```

**Subtitle** (30 chars max):
```
Exposure Bracketing Planner
```

**Primary Category**: Photo & Video
**Secondary Category**: Utilities

**Content Rights**: Does not contain, show, or access third-party content

**Age Rating**: 4+ (no objectionable content)

---

## Version Information

**Promotional Text** (170 chars max, can be updated without a new build):
```
Plan your HDR bracket sets before you shoot. Enter your metered exposures, see exactly which frames to capture. No ads, no subscriptions.
```

**Description** (4000 chars max):
```
HDR Calculator is a precision exposure bracketing tool for photographers who shoot HDR. Enter your shadow and highlight shutter speeds, and instantly see the bracket sets you need to capture.

Built for real estate, architecture, landscape, and interior photographers who need reliable HDR brackets every time.

HOW IT WORKS

1. Set your shadow (darkest) and highlight (brightest) metered shutter speeds
2. Choose your camera's AEB frame count (3, 5, 7, or 9)
3. Choose your EV spacing (1, 1.5, or 2 stops)
4. See your bracket sets instantly

The app calculates how many AEB sets you need and shows the exact shutter speeds for each set, displayed on clear tick-mark rulers.

CAMERA METERING

Skip the manual shutter speed entry. Tap the meter button next to either picker to open a live camera view. Point at the scene, tap to meter, and the app reads the exposure directly from your iPhone's camera. The metered value is mapped to the nearest standard 1/3-stop shutter speed.

FEATURES

- Full 1/3-stop shutter speed scale (1/8000s to 30s)
- Reactive results that update as you adjust any input
- Tick-mark ruler visualization for each bracket set
- Live camera metering with tap-to-expose
- Supports 3, 5, 7, or 9 frame AEB sets
- 1, 1.5, and 2 stop EV spacing options
- Adaptive light and dark mode
- iPad layout with side-by-side inputs and results
- VoiceOver and Dynamic Type support
- No ads, no subscriptions, no account required
- Works completely offline

PERFECT FOR

- Real estate photography
- Architecture and interior shoots
- Landscape HDR
- Any multi-exposure bracketing workflow

HDR Calculator does one thing and does it well. No bloat, no tutorials, no upsells. Just open it, enter your speeds, and shoot.
```

**Keywords** (100 chars max, comma-separated, no spaces after commas):
```
HDR,bracketing,exposure,calculator,photography,AEB,shutter,speed,bracket,real estate,metering
```
(96 characters)

**Support URL**:
```
https://github.com/[your-username]/hdr-calculator/issues
```
(Replace with your actual support URL or a simple landing page)

**Marketing URL** (optional):
```
(leave blank or add project page URL)
```

**Copyright**:
```
2026 Rob
```
(Adjust to your full name or business entity)

---

## Privacy Policy

**Privacy Policy URL**: Required. Since the app collects no data at all, you still need a hosted page. A simple GitHub Pages or static site works.

Draft privacy policy text (host this somewhere):

```
Privacy Policy for HDR Calculator

Last updated: February 14, 2026

HDR Calculator does not collect, store, or transmit any personal data.

Camera Access: The app requests camera permission solely to meter exposure
from the scene for shutter speed selection. Camera frames are processed
on-device in real time and are never recorded, stored, or transmitted.
No photos or video are captured or saved.

Analytics: None. The app contains no analytics, tracking, or crash
reporting frameworks.

Third-Party Services: None. The app makes no network requests.

Data Storage: All settings exist only in local app memory for the
duration of the session. Nothing is written to disk or synced.

Contact: [your email]
```

---

## App Privacy (App Store Privacy Labels)

**Data Collection**: Select **"No, we do not collect data from this app"**

The camera is used purely for real-time metering (no frames are saved or transmitted), so it does not constitute data collection under Apple's definitions.

---

## App Review Notes

```
This app is a standalone calculator for HDR photography exposure
bracketing. It requires no login or account.

Camera access is used only for live exposure metering (tap a scene to
read the shutter speed). No photos are taken or stored. If testing
camera metering, point the device at a well-lit area and tap the
camera preview to set a metering point.

To test the core functionality without a camera: adjust the shadow
and highlight shutter speed pickers and observe the bracket set
results update in real time.
```

---

## App Icon

Needs a 1024x1024 PNG (no alpha, no rounded corners) uploaded to App Store Connect.

The icon in Assets.xcassets should use the same design at all required sizes.

---

## Xcode Project Settings

**Bundle Identifier**:
```
com.[yourname].HDRCalculator
```
(Must be unique across the entire App Store. Register it in Certificates, Identifiers & Profiles at developer.apple.com.)

**Version**: `1.0.0` (displayed to users on the App Store)
**Build**: `1` (increment with each upload; App Store Connect rejects duplicate build numbers)

**Deployment Target**: iOS 17.0
**Supported Destinations**: iPhone, iPad
**Device Orientation**: Portrait (iPhone), All (iPad)

---

## Export Compliance

App Store Connect asks about encryption on every build upload.

**Does your app use encryption?**: **No**

This app uses no encryption, no HTTPS networking, no custom crypto. Select "No" when prompted. If you later add networking (e.g., for a support link using `WKWebView`), you would need to revisit this, but standard HTTPS via `NSURLSession`/`WKWebView` qualifies for the encryption exemption (select "Yes" then choose the CCATS exemption).

To skip the prompt on every upload, add this to Info.plist:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## Signing & Capabilities

- **Team**: Select your Apple Developer Program team in Xcode
- **Signing**: Automatic (let Xcode manage provisioning profiles)
- **Capabilities needed**: Camera (already handled by `NSCameraUsageDescription` in Info.plist, no entitlement needed)
- No push notifications, no App Groups, no iCloud, no HealthKit, no other entitlements

---

## What's New (for future updates)

Not needed for v1.0, but for subsequent versions, example format:
```
- Improved tick-mark ruler readability
- Bug fixes and performance improvements
```
Keep it concise. Max 4000 chars.

---

## Localization

**Primary Language**: English (U.S.)

No other localizations needed for MVP.

---

## Pricing & Availability

**Price**: Free (or choose a tier, e.g. $0.99 / $1.99)
**Availability**: All territories
**Pre-order**: No

---

## Checklist Before Submission

### Developer Account
- [ ] Apple Developer Program membership active ($99/year)
- [ ] Tax and banking agreements completed in App Store Connect (if charging)

### Xcode Project
- [ ] Bundle identifier registered at developer.apple.com
- [ ] Version set to `1.0.0`, Build set to `1`
- [ ] Signing team selected, automatic signing enabled
- [ ] `NSCameraUsageDescription` set in Info.plist
- [ ] `ITSAppUsesNonExemptEncryption` set to `false` in Info.plist
- [ ] App icon: 1024x1024 PNG in Assets.xcassets (no alpha, no rounded corners)
- [ ] All 6 test vectors passing in CalculatorTests
- [ ] Tested on physical device (camera metering)

### App Store Connect
- [ ] App record created with correct bundle ID
- [ ] App name, subtitle, description, keywords filled in
- [ ] Promotional text filled in
- [ ] Category set to Photo & Video
- [ ] Age rating questionnaire completed (4+)
- [ ] Copyright filled in
- [ ] Privacy policy hosted at a public URL and linked
- [ ] App Privacy set to "Does not collect data"
- [ ] App Review notes filled in
- [ ] Screenshots uploaded for required device sizes (not covered here)
- [ ] Build archived and uploaded via Xcode or Transporter
- [ ] Export compliance question answered (No encryption)
