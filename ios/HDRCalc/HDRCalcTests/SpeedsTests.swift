import XCTest
@testable import HDRCalc

final class SpeedsTests: XCTestCase {

    // MARK: - Table Structure

    func testTableHas55Entries() {
        XCTAssertEqual(speeds.count, 55)
    }

    func testFirstEntryIsFastest() {
        XCTAssertEqual(speeds[0].label, "1/8000")
    }

    func testLastEntryIsSlowest() {
        XCTAssertEqual(speeds[54].label, "30\"")
    }

    func testIndicesAreSequential() {
        for (i, speed) in speeds.enumerated() {
            XCTAssertEqual(speed.index, i, "Index mismatch at position \(i)")
        }
    }

    func testSecondsAreMonotonicallyIncreasing() {
        for i in 1..<speeds.count {
            XCTAssertGreaterThan(
                speeds[i].seconds, speeds[i - 1].seconds,
                "seconds not increasing at index \(i): \(speeds[i - 1].label) -> \(speeds[i].label)"
            )
        }
    }

    func testEVIsMonotonicallyDecreasing() {
        for i in 1..<speeds.count {
            XCTAssertLessThan(
                speeds[i].ev, speeds[i - 1].ev,
                "ev not decreasing at index \(i): \(speeds[i - 1].label) -> \(speeds[i].label)"
            )
        }
    }

    func testEVFormula() {
        // EV = log2(1/seconds)
        let speed = speeds[0] // 1/8000
        let expected = log2(1.0 / (1.0 / 8000.0))
        XCTAssertEqual(speed.ev, expected, accuracy: 0.001)
    }

    // MARK: - labelToIndex

    func testLabelToIndexKnownValues() {
        XCTAssertEqual(labelToIndex("1/8000"), 0)
        XCTAssertEqual(labelToIndex("1/1000"), 9)
        XCTAssertEqual(labelToIndex("1/125"), 18)
        XCTAssertEqual(labelToIndex("1/4"), 33)
        XCTAssertEqual(labelToIndex("1/2"), 36)
        XCTAssertEqual(labelToIndex("1\""), 39)
        XCTAssertEqual(labelToIndex("30\""), 54)
    }

    func testLabelToIndexUnknownReturnsNegativeOne() {
        XCTAssertEqual(labelToIndex("bogus"), -1)
        XCTAssertEqual(labelToIndex(""), -1)
    }

    // MARK: - nearestSpeed

    func testNearestSpeedExactMatch() {
        let result = nearestSpeed(seconds: 1.0 / 1000.0)
        XCTAssertEqual(result.label, "1/1000")
    }

    func testNearestSpeedApproximate() {
        // Slightly faster than 1/1000 should still map to 1/1000
        let result = nearestSpeed(seconds: 0.00095)
        XCTAssertEqual(result.label, "1/1000")
    }

    func testNearestSpeedBoundaryFast() {
        let result = nearestSpeed(seconds: 0.00001)
        XCTAssertEqual(result.label, "1/8000")
    }

    func testNearestSpeedBoundarySlow() {
        let result = nearestSpeed(seconds: 100.0)
        XCTAssertEqual(result.label, "30\"")
    }

    func testNearestSpeedHalfSecond() {
        let result = nearestSpeed(seconds: 0.5)
        XCTAssertEqual(result.label, "1/2")
    }

    // MARK: - EV difference via index distance

    func testEVDifferenceOneThirdStop() {
        // Adjacent entries are 1/3 stop apart
        let diff = Double(speeds[1].index - speeds[0].index) / 3.0
        XCTAssertEqual(diff, 1.0 / 3.0, accuracy: 0.001)
    }

    func testEVDifference1000to125() {
        // 1/1000 (index 9) to 1/125 (index 18) = 3 EV
        let diff = Double(labelToIndex("1/125") - labelToIndex("1/1000")) / 3.0
        XCTAssertEqual(diff, 3.0, accuracy: 0.001)
    }
}
