import SwiftUI

// MARK: - ViewModel

@Observable
final class CalculatorViewModel {
    var shadowIndex: Int = labelToIndex("1/4")
    var highlightIndex: Int = labelToIndex("1/1000")
    var frames: Int = 5
    var spacing: Double = 1.0

    var result: CalculationResult {
        calculate(
            shadowIndex: shadowIndex,
            highlightIndex: highlightIndex,
            frames: frames,
            spacing: spacing
        )
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var vm = CalculatorViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CameraConnectionService.self) private var connectionService
    @Environment(ShootingViewModel.self) private var shootingVM
    @State private var meterTarget: MeterTarget?
    @State private var showConnectSheet = false
    @State private var showConfirmSheet = false
    @State private var showProgressCover = false

    private enum MeterTarget: Identifiable {
        case shadow, highlight
        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: Theme.sectionGap) {
                    inputsSection
                        .frame(width: 360)
                    resultsSection
                }
                .padding(Theme.pagePaddingIPad)
            } else {
                VStack(spacing: Theme.sectionGap) {
                    inputsSection
                    resultsSection
                }
                .padding(Theme.pagePadding)
            }
        }
        .sheet(item: $meterTarget) { target in
            MeterView(selectedIndex: target == .shadow ? $vm.shadowIndex : $vm.highlightIndex)
        }
        .sheet(isPresented: $showConnectSheet) {
            CameraConnectView()
        }
        .sheet(isPresented: $showConfirmSheet) {
            ShootConfirmView(sets: vm.result.sets) {
                showConfirmSheet = false
                shootingVM.startShooting(sets: vm.result.sets)
                showProgressCover = true
            }
        }
        .fullScreenCover(isPresented: $showProgressCover) {
            ShootProgressView()
        }
        .onChange(of: shootingVM.phase) { _, newPhase in
            if case .idle = newPhase {
                showProgressCover = false
            }
        }
        .tint(.accentColor)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: vm.shadowIndex)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: vm.highlightIndex)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: vm.frames)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: vm.spacing)
    }

    // MARK: - Inputs

    private var inputsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
            Spacer().frame(height: Theme.sectionGap)
            speedPicker(label: "Shadows", selection: $vm.shadowIndex, target: .shadow)
            Spacer().frame(height: Theme.cardGap)
            speedPicker(label: "Highlights", selection: $vm.highlightIndex, target: .highlight)
            Spacer().frame(height: Theme.sectionGap)
            segmentedSection(label: "AEB Frames", tag: $vm.frames, options: [(3, "3"), (5, "5"), (7, "7"), (9, "9")])
            Spacer().frame(height: Theme.cardGap)
            segmentedSection(label: "EV Spacing", tag: $vm.spacing, options: [(1.0, "1"), (1.5, "1.5"), (2.0, "2")])
            Spacer().frame(height: Theme.sectionGap)
            connectCameraButton
        }
    }

    private var connectCameraButton: some View {
        Button {
            showConnectSheet = true
        } label: {
            HStack {
                Image(systemName: connectionService.isConnected ? "wifi" : "wifi.slash")
                Text(connectionService.connectedCameraName ?? "Connect Camera")
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(connectionService.isConnected ? .green : .accentColor)
    }

    private var titleRow: some View {
        HStack(spacing: 16) {
            Text("HDR Calc")
                .font(.title3.weight(.semibold))
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.cardBorder)
        }
    }

    private func speedPicker(label: String, selection: Binding<Int>, target: MeterTarget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    meterTarget = target
                } label: {
                    Image(systemName: "camera.metering.spot")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Picker(label, selection: selection) {
                ForEach(speeds, id: \.index) { speed in
                    Text(speed.label).tag(speed.index)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Segmented Controls

    private func segmentedSection<T: Hashable>(label: String, tag: Binding<T>, options: [(T, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)

            Picker(label, selection: tag) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            evRangeRow
            Spacer().frame(height: Theme.sectionGap)

            Text("Scene Dynamic Range")
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)

            if vm.result.rangeEv == 0 {
                Text("Single exposure needed. No bracketing required.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.top, 16)
            } else {
                summaryRow
                    .padding(.top, 8)
                Spacer().frame(height: Theme.sectionGap)
                setsSection
                if connectionService.isConnected {
                    Spacer().frame(height: Theme.sectionGap)
                    shootAllSetsButton
                }
            }
        }
    }

    private var evRangeRow: some View {
        HStack(spacing: 6) {
            Text(formatEV(vm.result.rangeEv))
                .font(.title3.weight(.semibold))
            Text("EV")
                .font(.title3.weight(.semibold))
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.cardBorder)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 8) {
            Text("\(vm.result.sets.count) set\(vm.result.sets.count > 1 ? "s" : "")")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Text("\u{00B7}")
                .foregroundStyle(.secondary.opacity(0.4))
            Text("\(vm.result.totalExposures) exposures")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    private var setsSection: some View {
        VStack(spacing: 16) {
            ForEach(Array(vm.result.sets.enumerated()), id: \.offset) { index, set in
                SetGroupView(setNumber: index + 1, speeds: set, colorIndex: index)
            }
        }
    }

    private func formatEV(_ ev: Double) -> String {
        let rounded = (ev * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }
}

// MARK: - Set Group View

struct SetGroupView: View {
    let setNumber: Int
    let speeds: [ShutterSpeed]
    let colorIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.setColor(colorIndex))
                    .frame(width: 8, height: 8)
                Text("Set \(setNumber)")
                    .font(.caption.weight(.medium))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }
            SetRulerView(speeds: speeds, colorIndex: colorIndex)
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius).fill(.cardBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set \(setNumber): \(speeds.map(\.label).joined(separator: ", "))")
    }
}

// MARK: - Set Ruler View

struct SetRulerView: View {
    let speeds: [ShutterSpeed]
    let colorIndex: Int

    private var centerIdx: Int {
        speeds.count / 2
    }

    var body: some View {
        GeometryReader { geo in
            let trackColor = Theme.setColor(colorIndex)

            // Track line
            Rectangle()
                .fill(trackColor.opacity(0.3))
                .frame(height: 2)
                .offset(y: 10)

            // Ticks
            ForEach(Array(speeds.enumerated()), id: \.offset) { j, speed in
                let pct = speeds.count > 1
                    ? CGFloat(j) / CGFloat(speeds.count - 1)
                    : 0.5
                let x = pct * geo.size.width
                let isCenter = j == centerIdx

                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isCenter ? Color.accentColor : Color.secondary)
                        .frame(width: isCenter ? 3 : 2, height: isCenter ? 16 : 12)
                        .opacity(isCenter ? 1.0 : 0.5)

                    Text(speed.label)
                        .font(isCenter ? .caption.weight(.semibold) : .caption2)
                        .foregroundStyle(isCenter ? Color.accentColor : .secondary)
                }
                .position(x: x, y: 20)
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 24)
    }
}

#Preview {
    ContentView()
}
