import Foundation

@Observable
final class ShootingViewModel {
    var phase: ShootingPhase = .idle
    var progress: ShootingProgress = .zero

    private var activeSets: [[ShutterSpeed]] = []

    var isShooting: Bool {
        phase == .shooting
    }

    var isComplete: Bool {
        if case .complete = phase { return true }
        return false
    }

    var isPaused: Bool {
        phase == .paused
    }

    // MARK: - Estimated Time

    func estimatedTime(for sets: [[ShutterSpeed]]) -> Int {
        guard !sets.isEmpty else { return 0 }
        // Sum all shutter speeds plus 1.5s overhead per frame for PTP command round-trip
        let totalSeconds = sets.flatMap { $0 }.reduce(0.0) { sum, speed in
            sum + speed.seconds + 1.5
        }
        return Int(totalSeconds.rounded(.up))
    }

    func formattedEstimatedTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        let m = seconds / 60
        let s = seconds % 60
        return "\(m)m \(s)s"
    }

    // MARK: - Speed Warnings

    func speedWarnings(for sets: [[ShutterSpeed]]) -> [SpeedWarning] {
        var warnings: [SpeedWarning] = []
        let allSpeeds = sets.flatMap { $0 }
        let maxSeconds = allSpeeds.map(\.seconds).max() ?? 0

        if maxSeconds >= 10 {
            warnings.append(SpeedWarning(
                message: "Exposures over 10s: use a sturdy tripod and remote trigger",
                severity: .caution
            ))
        }

        return warnings
    }

    // MARK: - Actions

    func startShooting(sets: [[ShutterSpeed]]) {
        activeSets = sets
        let totalFrames = sets.reduce(0) { $0 + $1.count }
        progress = ShootingProgress(
            completedFrames: 0,
            totalFrames: totalFrames,
            currentSet: 1,
            totalSets: sets.count
        )
        phase = .shooting
    }

    func cancel() {
        phase = .complete(.cancelled)
    }

    func retryRemaining() {
        phase = .shooting
    }

    func dismiss() {
        phase = .idle
        progress = .zero
        activeSets = []
    }

    // Test-only: set phase synchronously
    func _setPhaseForTesting(_ phase: ShootingPhase) {
        self.phase = phase
    }
}
