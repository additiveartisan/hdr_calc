import Foundation

// MARK: - Shutter Speed Components

struct ShutterSpeedComponents: Equatable {
    let numerator: Double
    let denominator: Double

    var seconds: Double { numerator / denominator }
}

// MARK: - App Label -> Components (for sending to camera)

func shutterspeedComponents(from speed: ShutterSpeed) -> ShutterSpeedComponents {
    let label = speed.label

    // Fraction format: "1/125", "1/8000", "1/2"
    if label.contains("/") {
        let parts = label.split(separator: "/")
        guard parts.count == 2,
              let num = Double(parts[0]),
              let den = Double(parts[1]) else {
            fatalError("Invalid fraction shutter speed label: \(label)")
        }
        return ShutterSpeedComponents(numerator: num, denominator: den)
    }

    // Seconds format: "2\"", "0.3\"", "1.3\""
    if label.hasSuffix("\"") {
        let numStr = String(label.dropLast())
        guard let value = Double(numStr) else {
            fatalError("Invalid seconds shutter speed label: \(label)")
        }

        // Whole seconds: "2\"" -> (2, 1)
        if value == value.rounded(.down) && value >= 1 {
            return ShutterSpeedComponents(numerator: value, denominator: 1)
        }

        // Decimal seconds: "0.3\"" -> (3, 10), "1.3\"" -> (13, 10)
        let num = value * 10
        return ShutterSpeedComponents(numerator: num, denominator: 10)
    }

    fatalError("Unknown shutter speed format: \(label)")
}

// MARK: - Components -> App Speed (for reading from camera)

func appShutterSpeed(fromNumerator numerator: Double, denominator: Double) -> ShutterSpeed {
    let seconds = numerator / denominator
    return nearestSpeed(seconds: seconds)
}

// MARK: - Speed Validation

struct SpeedValidationResult: Equatable {
    let allAvailable: Bool
    let substitutions: [SpeedSubstitution]

    static func == (lhs: SpeedValidationResult, rhs: SpeedValidationResult) -> Bool {
        lhs.allAvailable == rhs.allAvailable
            && lhs.substitutions.count == rhs.substitutions.count
            && zip(lhs.substitutions, rhs.substitutions).allSatisfy { $0 == $1 }
    }
}

struct SpeedSubstitution: Equatable {
    let original: ShutterSpeed
    let substitute: ShutterSpeed

    static func == (lhs: SpeedSubstitution, rhs: SpeedSubstitution) -> Bool {
        lhs.original.index == rhs.original.index && lhs.substitute.index == rhs.substitute.index
    }
}

func validateSpeeds(sets: [[ShutterSpeed]], available: [ShutterSpeed]) -> SpeedValidationResult {
    guard !available.isEmpty else {
        return SpeedValidationResult(allAvailable: false, substitutions: [])
    }

    var seen = Set<Int>()
    var substitutions: [SpeedSubstitution] = []

    for set in sets {
        for speed in set {
            guard !seen.contains(speed.index) else { continue }
            seen.insert(speed.index)

            let isAvailable = available.contains { $0.index == speed.index }
            if !isAvailable {
                let nearest = available.min(by: {
                    abs($0.seconds - speed.seconds) < abs($1.seconds - speed.seconds)
                })!
                substitutions.append(SpeedSubstitution(original: speed, substitute: nearest))
            }
        }
    }

    return SpeedValidationResult(
        allAvailable: substitutions.isEmpty,
        substitutions: substitutions
    )
}
