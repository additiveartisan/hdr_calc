import SwiftUI

struct ShootConfirmView: View {
    let sets: [[ShutterSpeed]]
    let onShoot: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var shootingVM = ShootingViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionGap) {
                    summarySection
                    if !shootingVM.speedWarnings(for: sets).isEmpty {
                        warningsSection
                    }
                    exposuresSection
                }
                .padding(Theme.pagePadding)
            }
            .navigationTitle("Confirm Shooting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                shootButton
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: Theme.cardGap) {
            HStack {
                Label("\(sets.count) set\(sets.count > 1 ? "s" : "")", systemImage: "square.stack.3d.up")
                Spacer()
                Label(
                    "\(sets.reduce(0) { $0 + $1.count }) exposures",
                    systemImage: "camera.shutter.button"
                )
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                let time = shootingVM.estimatedTime(for: sets)
                Text("Estimated time: \(shootingVM.formattedEstimatedTime(time))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.cardPadding)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius).fill(.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.cardBorder, lineWidth: 1))
    }

    // MARK: - Warnings

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(shootingVM.speedWarnings(for: sets), id: \.message) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: warning.severity == .critical ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundStyle(warning.severity == .critical ? .red : .orange)
                    Text(warning.message)
                        .font(.subheadline)
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius).fill(.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.orange.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Exposures

    private var exposuresSection: some View {
        VStack(alignment: .leading, spacing: Theme.cardGap) {
            Text("Exposure Sets")
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)

            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                SetGroupView(setNumber: index + 1, speeds: set, colorIndex: index)
            }
        }
    }

    // MARK: - Shoot Button

    private var shootButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                onShoot()
            } label: {
                HStack {
                    Image(systemName: "camera.shutter.button")
                    Text("Shoot All Sets")
                }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(Theme.pagePadding)
        }
        .background(.bar)
    }
}

#Preview {
    ShootConfirmView(
        sets: [
            [speeds[15], speeds[12], speeds[9], speeds[6], speeds[3]],
            [speeds[3], speeds[0], speeds[0], speeds[0], speeds[0]],
        ],
        onShoot: {}
    )
}
