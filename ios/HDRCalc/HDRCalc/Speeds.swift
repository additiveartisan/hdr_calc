import Foundation

struct ShutterSpeed: Equatable, Identifiable {
    let index: Int
    let label: String
    let seconds: Double
    var ev: Double { log2(1.0 / seconds) }
    var id: Int { index }
}

let speeds: [ShutterSpeed] = [
    ShutterSpeed(index: 0,  label: "1/8000", seconds: 1.0/8000),
    ShutterSpeed(index: 1,  label: "1/6400", seconds: 1.0/6400),
    ShutterSpeed(index: 2,  label: "1/5000", seconds: 1.0/5000),
    ShutterSpeed(index: 3,  label: "1/4000", seconds: 1.0/4000),
    ShutterSpeed(index: 4,  label: "1/3200", seconds: 1.0/3200),
    ShutterSpeed(index: 5,  label: "1/2500", seconds: 1.0/2500),
    ShutterSpeed(index: 6,  label: "1/2000", seconds: 1.0/2000),
    ShutterSpeed(index: 7,  label: "1/1600", seconds: 1.0/1600),
    ShutterSpeed(index: 8,  label: "1/1250", seconds: 1.0/1250),
    ShutterSpeed(index: 9,  label: "1/1000", seconds: 1.0/1000),
    ShutterSpeed(index: 10, label: "1/800",  seconds: 1.0/800),
    ShutterSpeed(index: 11, label: "1/640",  seconds: 1.0/640),
    ShutterSpeed(index: 12, label: "1/500",  seconds: 1.0/500),
    ShutterSpeed(index: 13, label: "1/400",  seconds: 1.0/400),
    ShutterSpeed(index: 14, label: "1/320",  seconds: 1.0/320),
    ShutterSpeed(index: 15, label: "1/250",  seconds: 1.0/250),
    ShutterSpeed(index: 16, label: "1/200",  seconds: 1.0/200),
    ShutterSpeed(index: 17, label: "1/160",  seconds: 1.0/160),
    ShutterSpeed(index: 18, label: "1/125",  seconds: 1.0/125),
    ShutterSpeed(index: 19, label: "1/100",  seconds: 1.0/100),
    ShutterSpeed(index: 20, label: "1/80",   seconds: 1.0/80),
    ShutterSpeed(index: 21, label: "1/60",   seconds: 1.0/60),
    ShutterSpeed(index: 22, label: "1/50",   seconds: 1.0/50),
    ShutterSpeed(index: 23, label: "1/40",   seconds: 1.0/40),
    ShutterSpeed(index: 24, label: "1/30",   seconds: 1.0/30),
    ShutterSpeed(index: 25, label: "1/25",   seconds: 1.0/25),
    ShutterSpeed(index: 26, label: "1/20",   seconds: 1.0/20),
    ShutterSpeed(index: 27, label: "1/15",   seconds: 1.0/15),
    ShutterSpeed(index: 28, label: "1/13",   seconds: 1.0/13),
    ShutterSpeed(index: 29, label: "1/10",   seconds: 1.0/10),
    ShutterSpeed(index: 30, label: "1/8",    seconds: 1.0/8),
    ShutterSpeed(index: 31, label: "1/6",    seconds: 1.0/6),
    ShutterSpeed(index: 32, label: "1/5",    seconds: 1.0/5),
    ShutterSpeed(index: 33, label: "1/4",    seconds: 1.0/4),
    ShutterSpeed(index: 34, label: "0.3\"",  seconds: 0.3),
    ShutterSpeed(index: 35, label: "0.4\"",  seconds: 0.4),
    ShutterSpeed(index: 36, label: "1/2",    seconds: 1.0/2),
    ShutterSpeed(index: 37, label: "0.6\"",  seconds: 0.6),
    ShutterSpeed(index: 38, label: "0.8\"",  seconds: 0.8),
    ShutterSpeed(index: 39, label: "1\"",    seconds: 1.0),
    ShutterSpeed(index: 40, label: "1.3\"",  seconds: 1.3),
    ShutterSpeed(index: 41, label: "1.6\"",  seconds: 1.6),
    ShutterSpeed(index: 42, label: "2\"",    seconds: 2.0),
    ShutterSpeed(index: 43, label: "2.5\"",  seconds: 2.5),
    ShutterSpeed(index: 44, label: "3.2\"",  seconds: 3.2),
    ShutterSpeed(index: 45, label: "4\"",    seconds: 4.0),
    ShutterSpeed(index: 46, label: "5\"",    seconds: 5.0),
    ShutterSpeed(index: 47, label: "6\"",    seconds: 6.0),
    ShutterSpeed(index: 48, label: "8\"",    seconds: 8.0),
    ShutterSpeed(index: 49, label: "10\"",   seconds: 10.0),
    ShutterSpeed(index: 50, label: "13\"",   seconds: 13.0),
    ShutterSpeed(index: 51, label: "15\"",   seconds: 15.0),
    ShutterSpeed(index: 52, label: "20\"",   seconds: 20.0),
    ShutterSpeed(index: 53, label: "25\"",   seconds: 25.0),
    ShutterSpeed(index: 54, label: "30\"",   seconds: 30.0),
]

func labelToIndex(_ label: String) -> Int {
    speeds.first(where: { $0.label == label })!.index
}

func nearestSpeed(seconds: Double) -> ShutterSpeed {
    speeds.min(by: { abs($0.seconds - seconds) < abs($1.seconds - seconds) })!
}
