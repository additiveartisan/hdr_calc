import Foundation

struct CalculationResult {
    let rangeEv: Double
    let sets: [[ShutterSpeed]]
    let totalExposures: Int
}

private func buildSet(start: Int, frames: Int, step: Double) -> [ShutterSpeed] {
    var indices = [start]
    var current = Double(start)
    for _ in 1..<frames {
        current = (current + step).rounded(.up)
        let clamped = max(0, min(Int(current), speeds.count - 1))
        indices.append(clamped)
        current = Double(clamped)
    }
    return indices.map { speeds[$0] }
}

func calculate(shadowIndex: Int, highlightIndex: Int, frames: Int, spacing: Double) -> CalculationResult {
    let bright = min(shadowIndex, highlightIndex)
    let dark = max(shadowIndex, highlightIndex)
    let rangeEv = Double(dark - bright) / 3.0

    if rangeEv <= 0 {
        return CalculationResult(rangeEv: 0, sets: [], totalExposures: 1)
    }

    let step = spacing * 3.0
    let coverage = Double(frames - 1) * spacing
    var sets: [[ShutterSpeed]] = []
    var setStart = bright

    if rangeEv <= coverage {
        let set = buildSet(start: setStart, frames: frames, step: step)
        sets.append(set)
    } else {
        for _ in 0..<50 {
            let set = buildSet(start: setStart, frames: frames, step: step)
            sets.append(set)
            let lastIndex = set.last!.index
            if lastIndex > dark { break }
            setStart = lastIndex
        }
    }

    return CalculationResult(rangeEv: rangeEv, sets: sets, totalExposures: sets.count * frames)
}
