import Foundation

struct CalculationResult {
    let rangeEv: Double
    let sets: [[ShutterSpeed]]
    let totalExposures: Int
}

func calculate(shadowIndex: Int, highlightIndex: Int, frames: Int, spacing: Double) -> CalculationResult {
    let bright = min(shadowIndex, highlightIndex)
    let dark = max(shadowIndex, highlightIndex)
    let rangeEV = Double(dark - bright) / 3.0

    if rangeEV <= 0 {
        return CalculationResult(rangeEv: 0, sets: [], totalExposures: 1)
    }

    let step = spacing * 3.0
    let coverage = Double(frames - 1) * spacing

    if rangeEV <= coverage {
        let set = buildSet(start: bright, frames: frames, step: step)
        return CalculationResult(rangeEv: rangeEV, sets: [set], totalExposures: frames)
    }

    var sets: [[ShutterSpeed]] = []
    var setStart = bright
    for _ in 0..<50 {
        let set = buildSet(start: setStart, frames: frames, step: step)
        sets.append(set)
        let lastIndex = set.last!.index
        if lastIndex > dark { break }
        setStart = lastIndex
    }

    return CalculationResult(rangeEv: rangeEV, sets: sets, totalExposures: sets.count * frames)
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
