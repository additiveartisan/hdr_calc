import Foundation

struct ShutterSpeed {
    let index: Int
    let label: String
    let seconds: Double
    let ev: Double
}

private let table: [(String, Double)] = [
    ("1/8000", 1.0 / 8000),
    ("1/6400", 1.0 / 6400),
    ("1/5000", 1.0 / 5000),
    ("1/4000", 1.0 / 4000),
    ("1/3200", 1.0 / 3200),
    ("1/2500", 1.0 / 2500),
    ("1/2000", 1.0 / 2000),
    ("1/1600", 1.0 / 1600),
    ("1/1250", 1.0 / 1250),
    ("1/1000", 1.0 / 1000),
    ("1/800",  1.0 / 800),
    ("1/640",  1.0 / 640),
    ("1/500",  1.0 / 500),
    ("1/400",  1.0 / 400),
    ("1/320",  1.0 / 320),
    ("1/250",  1.0 / 250),
    ("1/200",  1.0 / 200),
    ("1/160",  1.0 / 160),
    ("1/125",  1.0 / 125),
    ("1/100",  1.0 / 100),
    ("1/80",   1.0 / 80),
    ("1/60",   1.0 / 60),
    ("1/50",   1.0 / 50),
    ("1/40",   1.0 / 40),
    ("1/30",   1.0 / 30),
    ("1/25",   1.0 / 25),
    ("1/20",   1.0 / 20),
    ("1/15",   1.0 / 15),
    ("1/13",   1.0 / 13),
    ("1/10",   1.0 / 10),
    ("1/8",    1.0 / 8),
    ("1/6",    1.0 / 6),
    ("1/5",    1.0 / 5),
    ("1/4",    1.0 / 4),
    ("0.3\"",  0.3),
    ("0.4\"",  0.4),
    ("1/2",    0.5),
    ("0.6\"",  0.6),
    ("0.8\"",  0.8),
    ("1\"",    1.0),
    ("1.3\"",  1.3),
    ("1.6\"",  1.6),
    ("2\"",    2.0),
    ("2.5\"",  2.5),
    ("3.2\"",  3.2),
    ("4\"",    4.0),
    ("5\"",    5.0),
    ("6\"",    6.0),
    ("8\"",    8.0),
    ("10\"",   10.0),
    ("13\"",   13.0),
    ("15\"",   15.0),
    ("20\"",   20.0),
    ("25\"",   25.0),
    ("30\"",   30.0),
]

let speeds: [ShutterSpeed] = table.enumerated().map { index, entry in
    ShutterSpeed(
        index: index,
        label: entry.0,
        seconds: entry.1,
        ev: log2(1.0 / entry.1)
    )
}

private let labelMap: [String: Int] = Dictionary(uniqueKeysWithValues: speeds.map { ($0.label, $0.index) })

func labelToIndex(_ label: String) -> Int {
    labelMap[label] ?? -1
}

func nearestSpeed(seconds: Double) -> ShutterSpeed {
    speeds.min(by: { abs($0.seconds - seconds) < abs($1.seconds - seconds) })!
}
