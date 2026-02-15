import SwiftUI

struct ShootProgressView: View {
    @Environment(ShootingViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            switch vm.phase {
            case .shooting:
                shootingContent
            case .paused:
                pausedContent
            case .complete(let result):
                completeContent(result: result)
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Shooting

    private var shootingContent: some View {
        VStack(spacing: Theme.sectionGap) {
            Spacer()

            progressRing

            Text(vm.progress.setProgress)
                .font(.title3.weight(.semibold))
            Text(vm.progress.frameProgress)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                vm.cancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, Theme.sectionGap)
        }
    }

    // MARK: - Paused

    private var pausedContent: some View {
        VStack(spacing: Theme.sectionGap) {
            Spacer()

            Image(systemName: "pause.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Paused")
                .font(.title3.weight(.semibold))
            Text(vm.progress.frameProgress)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                vm.cancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, Theme.sectionGap)
        }
    }

    // MARK: - Complete

    private func completeContent(result: ShootingResult) -> some View {
        VStack(spacing: Theme.sectionGap) {
            Spacer()

            switch result {
            case .success(let count):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("Complete")
                    .font(.title3.weight(.semibold))
                Text("\(count) frames captured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            case .partial(let captured, let total):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                Text("Partially Complete")
                    .font(.title3.weight(.semibold))
                Text("\(captured) of \(total) frames captured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                Text("Cancelled")
                    .font(.title3.weight(.semibold))
                Text(vm.progress.frameProgress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                Text("Failed")
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.pagePadding)
            }

            Spacer()

            VStack(spacing: Theme.cardGap) {
                if case .partial = result {
                    Button {
                        vm.retryRemaining()
                    } label: {
                        Text("Retry Remaining")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    vm.dismiss()
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, Theme.sectionGap)
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(.cardBorder, lineWidth: 8)
                .frame(width: 120, height: 120)
            Circle()
                .trim(from: 0, to: vm.progress.fractionComplete)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
            Text("\(Int(vm.progress.fractionComplete * 100))%")
                .font(.title2.weight(.semibold).monospacedDigit())
        }
    }
}

// MARK: - ShootingResult helpers

extension ShootingResult {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

#Preview("Shooting") {
    let vm = ShootingViewModel()
    vm._setPhaseForTesting(.shooting)
    vm.progress = ShootingProgress(completedFrames: 5, totalFrames: 15, currentSet: 1, totalSets: 3)
    return ShootProgressView()
        .environment(vm)
}

#Preview("Complete") {
    let vm = ShootingViewModel()
    vm._setPhaseForTesting(.complete(.success(framesCaptured: 15)))
    return ShootProgressView()
        .environment(vm)
}
