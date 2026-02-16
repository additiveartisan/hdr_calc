import Foundation
import os

private let logger = Logger(subsystem: "com.hdr-calc", category: "ShootingViewModel")

@Observable
final class ShootingViewModel {
    var phase: ShootingPhase = .idle
    var progress: ShootingProgress = .zero

    static let perFrameOverheadSeconds: Double = 2.5
    static let maxShutterRetries: Int = 3
    static let retryDelay: Duration = .milliseconds(300)

    private let hardware: any CameraHardwareProtocol
    private var activeSets: [[ShutterSpeed]] = []
    private var shootingTask: Task<Void, Never>?

    init(hardware: any CameraHardwareProtocol = StubCameraHardware()) {
        self.hardware = hardware
    }

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
        let totalSeconds = sets.flatMap { $0 }.reduce(0.0) { sum, speed in
            sum + speed.seconds + Self.perFrameOverheadSeconds
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
        executeShootingLoop(sets: sets)
    }

    func cancel() {
        shootingTask?.cancel()
        shootingTask = nil
        phase = .idle
        progress = .zero
        activeSets = []
    }

    func retryRemaining() {
        phase = .shooting
        executeShootingLoop(sets: activeSets)
    }

    func dismiss() {
        shootingTask?.cancel()
        shootingTask = nil
        phase = .idle
        progress = .zero
        activeSets = []
    }

    // MARK: - Shooting Loop

    private func executeShootingLoop(sets: [[ShutterSpeed]]) {
        shootingTask?.cancel()
        shootingTask = Task { @MainActor in
            // Pre-shoot mode check
            do {
                let mode = try await hardware.readExposureMode()
                if mode != .manual {
                    phase = .complete(.failed("Camera is not in Manual mode"))
                    return
                }
            } catch is CancellationError {
                return
            } catch {
                phase = .complete(.failed("Camera disconnected. Reconnect and retry."))
                return
            }

            var completed = progress.completedFrames
            var completedSets = 0

            for (setIndex, set) in sets.enumerated() {
                guard !Task.isCancelled, phase == .shooting else { return }
                progress.currentSet = setIndex + 1
                var setSucceeded = true

                for speed in set {
                    guard !Task.isCancelled, phase == .shooting else { return }

                    // 1. Set shutter speed
                    progress.currentFrameStatus = .settingShutter(speed)
                    do {
                        try await hardware.setShutterSpeed(speed)
                    } catch is CancellationError {
                        return
                    } catch {
                        logger.error("Failed to set shutter speed \(speed.label): \(error.localizedDescription)")
                        setSucceeded = false
                        break
                    }

                    // 2. Verify with retry
                    var verified = false
                    for attempt in 1...Self.maxShutterRetries {
                        guard !Task.isCancelled, phase == .shooting else { return }
                        progress.currentFrameStatus = .verifyingShutter(attempt: attempt, maxAttempts: Self.maxShutterRetries)

                        try? await Task.sleep(for: Self.retryDelay)
                        guard !Task.isCancelled, phase == .shooting else { return }

                        do {
                            let readBack = try await hardware.readShutterSpeed()
                            if readBack.index == speed.index {
                                verified = true
                                break
                            }
                            logger.warning("Shutter verify mismatch: requested \(speed.label), got \(readBack.label) (attempt \(attempt)/\(Self.maxShutterRetries))")
                        } catch is CancellationError {
                            return
                        } catch let error as CameraHardwareError where error == .disconnected {
                            phase = .complete(.failed("Camera disconnected. Reconnect and retry."))
                            return
                        } catch {
                            logger.error("Shutter verify read failed: \(error.localizedDescription)")
                            setSucceeded = false
                            break
                        }
                    }

                    if !verified {
                        logger.error("Shutter speed verification failed after \(Self.maxShutterRetries) attempts for \(speed.label)")
                        setSucceeded = false
                        break
                    }

                    // 3. Capture
                    progress.currentFrameStatus = .capturing(speed)
                    do {
                        try await hardware.captureAndWaitForBuffer()
                    } catch is CancellationError {
                        return
                    } catch let error as CameraHardwareError where error == .disconnected {
                        phase = .complete(.failed("Camera disconnected. Reconnect and retry."))
                        return
                    } catch {
                        logger.error("Capture failed for \(speed.label): \(error.localizedDescription)")
                        setSucceeded = false
                        break
                    }

                    progress.currentFrameStatus = .waitingForBuffer
                    completed += 1
                    progress.completedFrames = completed
                }

                if setSucceeded {
                    completedSets += 1
                } else {
                    // A set with gaps is unusable; stop and report partial
                    break
                }
            }

            guard !Task.isCancelled else { return }
            progress.currentFrameStatus = .idle

            if completedSets == sets.count {
                phase = .complete(.success(framesCaptured: completed))
            } else if completedSets > 0 {
                phase = .complete(.partial(framesCaptured: completed, totalExpected: progress.totalFrames))
            } else {
                phase = .complete(.failed("All sets failed. Check camera connection and settings."))
            }
        }
    }

    // Test-only: set phase synchronously
    func _setPhaseForTesting(_ phase: ShootingPhase) {
        self.phase = phase
    }
}
