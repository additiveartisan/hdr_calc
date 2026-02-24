import SwiftUI

// MARK: - Mockup: Updated Title Row (single camera button)

/// Shows the proposed ContentView title row with the camera button
/// moved from each picker into the title bar alongside the help button.
struct MockupTitleRow: View {
    var body: some View {
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
        }
        .padding(Theme.pagePadding)
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

/// Simulates the camera meter view at different phases of the two-step flow.
/// Uses a gradient background to stand in for the live camera preview.
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
                        Text(buttonLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
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
            // Gradient simulating a scene with shadows and highlights
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
