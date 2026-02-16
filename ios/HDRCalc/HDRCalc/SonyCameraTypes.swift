import Foundation

// MARK: - Exposure Mode

enum ExposureMode: Equatable {
    case manual
    case aperturePriority
    case shutterPriority
    case programAuto
    case unknown
}

// MARK: - Camera Hardware Errors

enum CameraHardwareError: Error, Equatable {
    case shutterSpeedMismatch(requested: String, actual: String)
    case captureTimeout
    case wrongExposureMode(ExposureMode)
    case disconnected
}

// MARK: - Connection

enum ConnectionState: Equatable {
    case disconnected
    case discovering
    case connecting(DiscoveredCamera)
    case modeCheck(DiscoveredCamera)
    case connected(DiscoveredCamera)
    case wrongMode(DiscoveredCamera, ExposureMode)
    case error(String)

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): true
        case (.discovering, .discovering): true
        case (.connecting(let a), .connecting(let b)): a.id == b.id
        case (.modeCheck(let a), .modeCheck(let b)): a.id == b.id
        case (.connected(let a), .connected(let b)): a.id == b.id
        case (.wrongMode(let ac, let am), .wrongMode(let bc, let bm)): ac.id == bc.id && am == bm
        case (.error(let a), .error(let b)): a == b
        default: false
        }
    }
}

struct DiscoveredCamera: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
}

// MARK: - Shooting

enum ShootingPhase: Equatable {
    case idle
    case confirming
    case shooting
    case paused
    case complete(ShootingResult)
}

enum FrameStatus: Equatable {
    case idle
    case settingShutter(ShutterSpeed)
    case verifyingShutter(attempt: Int, maxAttempts: Int)
    case capturing(ShutterSpeed)
    case waitingForBuffer

    static func == (lhs: FrameStatus, rhs: FrameStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): true
        case (.settingShutter(let a), .settingShutter(let b)): a.index == b.index
        case (.verifyingShutter(let aa, let am), .verifyingShutter(let ba, let bm)): aa == ba && am == bm
        case (.capturing(let a), .capturing(let b)): a.index == b.index
        case (.waitingForBuffer, .waitingForBuffer): true
        default: false
        }
    }
}

struct ShootingProgress: Equatable {
    var completedFrames: Int
    var totalFrames: Int
    var currentSet: Int
    var totalSets: Int
    var currentFrameStatus: FrameStatus = .idle

    var fractionComplete: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(completedFrames) / Double(totalFrames)
    }

    var setProgress: String {
        "Set \(currentSet) of \(totalSets)"
    }

    var frameProgress: String {
        "\(completedFrames) of \(totalFrames) frames"
    }

    static let zero = ShootingProgress(completedFrames: 0, totalFrames: 0, currentSet: 0, totalSets: 0)
}

enum ShootingResult: Equatable {
    case success(framesCaptured: Int)
    case partial(framesCaptured: Int, totalExpected: Int)
    case cancelled
    case failed(String)
}

struct SpeedWarning: Equatable {
    let message: String
    let severity: Severity

    enum Severity: Equatable {
        case info
        case caution
        case critical
    }
}
