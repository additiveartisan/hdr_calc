import SwiftUI

// MARK: - Mockup Runner (temporary, delete before implementation)

/// Wrap the real app entry point so we can show mockups instead.
/// To revert: delete this file entirely.
struct MockupRunner: View {
    @State private var selectedTab = 0

    private let tabs = [
        "Title Row",
        "Shadows: Initial",
        "Shadows: Metered",
        "Highlights: Initial",
        "Highlights: Metered"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Tab content
            TabView(selection: $selectedTab) {
                MockupTitleRow()
                    .tag(0)
                MockupMeterView(phase: .shadow, hasSpeed: false)
                    .tag(1)
                MockupMeterView(phase: .shadow, hasSpeed: true)
                    .tag(2)
                MockupMeterView(phase: .highlight, hasSpeed: false)
                    .tag(3)
                MockupMeterView(phase: .highlight, hasSpeed: true)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom bar
            VStack(spacing: 8) {
                Text(tabs[selectedTab])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Swipe left/right to see all mockups")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Dots
                HStack(spacing: 6) {
                    ForEach(0..<tabs.count, id: \.self) { i in
                        Circle()
                            .fill(i == selectedTab ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }
}

// MARK: - Mockup: Updated Title Row (single camera button)

struct MockupTitleRow: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title row with single camera button
                HStack(spacing: 16) {
                    Text("HDR Calc")
                        .font(.title3.weight(.semibold))
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.cardBorder)
                    Button {} label: {
                        Image(systemName: "camera.metering.spot")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    Button {} label: {
                        Text("?")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: Theme.sectionGap)

                // Shadows picker - no camera button
                pickerSection(label: "Shadows", value: "1/4")

                Spacer().frame(height: Theme.cardGap)

                // Highlights picker - no camera button
                pickerSection(label: "Highlights", value: "1/1000")

                Spacer().frame(height: Theme.sectionGap)

                // Annotation
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                    Text("Single camera button in title bar opens two-step metering flow")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.cardBackground))
            }
            .padding(Theme.pagePadding)
        }
    }

    private func pickerSection(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(.cardBackground)
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(.cardBorder, lineWidth: 1)
                Text(value)
                    .font(.title3.monospacedDigit())
            }
            .frame(height: 120)
        }
    }
}

// MARK: - Mockup: Meter View States

struct MockupMeterView: View {
    let phase: MeterMockPhase
    let hasSpeed: Bool

    enum MeterMockPhase {
        case shadow
        case highlight
    }

    private var phaseTitle: String {
        switch phase {
        case .shadow:    return "Step 1 of 2: Meter Shadows"
        case .highlight: return "Step 2 of 2: Meter Highlights"
        }
    }

    private var instruction: String {
        switch phase {
        case .shadow:    return "Tap the darkest area"
        case .highlight: return "Tap the brightest area"
        }
    }

    private var buttonLabel: String {
        switch phase {
        case .shadow:    return "Use for Shadows"
        case .highlight: return "Use for Highlights"
        }
    }

    private var mockSpeed: String {
        switch phase {
        case .shadow:    return "1/4"
        case .highlight: return "1/1000"
        }
    }

    private var reticleOffset: CGPoint {
        switch phase {
        case .shadow:    return CGPoint(x: -40, y: -80)
        case .highlight: return CGPoint(x: 50, y: -120)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Fake camera preview
                cameraPlaceholder
                    .ignoresSafeArea()

                // Reticle (shown when speed is metered)
                if hasSpeed {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                        .offset(x: reticleOffset.x, y: reticleOffset.y)
                }

                // Bottom controls
                VStack(spacing: 12) {
                    Text(instruction)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())

                    if hasSpeed {
                        Text(mockSpeed)
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    Button {} label: {
                        HStack {
                            Image(systemName: "camera.metering.spot")
                            Text(buttonLabel)
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasSpeed)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle(phaseTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {} label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }

    private var cameraPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(white: 0.15),
                    Color(white: 0.3),
                    Color(white: 0.5),
                    Color(white: 0.7),
                    Color(white: 0.85)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )

            // Grid overlay to suggest camera feel
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.05))
                        .frame(height: 1)
                    Spacer()
                }
            }
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 1)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("1. Title Row (single camera btn)") {
    MockupTitleRow()
}

#Preview("2. Shadows - initial") {
    MockupMeterView(phase: .shadow, hasSpeed: false)
}

#Preview("3. Shadows - speed metered") {
    MockupMeterView(phase: .shadow, hasSpeed: true)
}

#Preview("4. Highlights - initial") {
    MockupMeterView(phase: .highlight, hasSpeed: false)
}

#Preview("5. Highlights - speed metered") {
    MockupMeterView(phase: .highlight, hasSpeed: true)
}
