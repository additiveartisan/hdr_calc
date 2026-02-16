import XCTest
@testable import HDRCalc

final class ShutterSpeedMappingTests: XCTestCase {

    // Helper to look up a speed by label
    private func speed(_ label: String) -> ShutterSpeed {
        let idx = labelToIndex(label)
        precondition(idx >= 0, "Unknown speed label: \(label)")
        return speeds[idx]
    }

    // MARK: - shutterspeedComponents: Fraction Format

    func testComponents_fraction_1_125() {
        let c = shutterspeedComponents(from: speed("1/125"))
        XCTAssertEqual(c.numerator, 1)
        XCTAssertEqual(c.denominator, 125)
    }

    func testComponents_fraction_1_8000() {
        let c = shutterspeedComponents(from: speed("1/8000"))
        XCTAssertEqual(c.numerator, 1)
        XCTAssertEqual(c.denominator, 8000)
    }

    func testComponents_fraction_1_2() {
        // "1/2" is a fraction (0.5 seconds), not a decimal seconds label
        let c = shutterspeedComponents(from: speed("1/2"))
        XCTAssertEqual(c.numerator, 1)
        XCTAssertEqual(c.denominator, 2)
    }

    func testComponents_fraction_1_4() {
        let c = shutterspeedComponents(from: speed("1/4"))
        XCTAssertEqual(c.numerator, 1)
        XCTAssertEqual(c.denominator, 4)
    }

    // MARK: - shutterspeedComponents: Whole Seconds

    func testComponents_wholeSeconds_1() {
        let c = shutterspeedComponents(from: speed("1\""))
        XCTAssertEqual(c.numerator, 1)
        XCTAssertEqual(c.denominator, 1)
    }

    func testComponents_wholeSeconds_2() {
        let c = shutterspeedComponents(from: speed("2\""))
        XCTAssertEqual(c.numerator, 2)
        XCTAssertEqual(c.denominator, 1)
    }

    func testComponents_wholeSeconds_30() {
        let c = shutterspeedComponents(from: speed("30\""))
        XCTAssertEqual(c.numerator, 30)
        XCTAssertEqual(c.denominator, 1)
    }

    func testComponents_wholeSeconds_5() {
        let c = shutterspeedComponents(from: speed("5\""))
        XCTAssertEqual(c.numerator, 5)
        XCTAssertEqual(c.denominator, 1)
    }

    // MARK: - shutterspeedComponents: Decimal Seconds

    func testComponents_decimalSeconds_0_3() {
        let c = shutterspeedComponents(from: speed("0.3\""))
        XCTAssertEqual(c.numerator, 3)
        XCTAssertEqual(c.denominator, 10)
    }

    func testComponents_decimalSeconds_0_4() {
        let c = shutterspeedComponents(from: speed("0.4\""))
        XCTAssertEqual(c.numerator, 4)
        XCTAssertEqual(c.denominator, 10)
    }

    func testComponents_decimalSeconds_0_6() {
        let c = shutterspeedComponents(from: speed("0.6\""))
        XCTAssertEqual(c.numerator, 6)
        XCTAssertEqual(c.denominator, 10)
    }

    func testComponents_decimalSeconds_0_8() {
        let c = shutterspeedComponents(from: speed("0.8\""))
        XCTAssertEqual(c.numerator, 8)
        XCTAssertEqual(c.denominator, 10)
    }

    func testComponents_decimalSeconds_1_3() {
        let c = shutterspeedComponents(from: speed("1.3\""))
        XCTAssertEqual(c.numerator, 13)
        XCTAssertEqual(c.denominator, 10)
    }

    func testComponents_decimalSeconds_1_6() {
        let c = shutterspeedComponents(from: speed("1.6\""))
        XCTAssertEqual(c.numerator, 16)
        XCTAssertEqual(c.denominator, 10)
    }

    func testComponents_decimalSeconds_2_5() {
        let c = shutterspeedComponents(from: speed("2.5\""))
        XCTAssertEqual(c.numerator, 25)
        XCTAssertEqual(c.denominator, 10)
    }

    func testComponents_decimalSeconds_3_2() {
        let c = shutterspeedComponents(from: speed("3.2\""))
        XCTAssertEqual(c.numerator, 32)
        XCTAssertEqual(c.denominator, 10)
    }

    // MARK: - appShutterSpeed: Reverse Mapping

    func testReverse_fraction_1_125() {
        let result = appShutterSpeed(fromNumerator: 1, denominator: 125)
        XCTAssertEqual(result.label, "1/125")
    }

    func testReverse_fraction_1_8000() {
        let result = appShutterSpeed(fromNumerator: 1, denominator: 8000)
        XCTAssertEqual(result.label, "1/8000")
    }

    func testReverse_wholeSeconds_2() {
        let result = appShutterSpeed(fromNumerator: 2, denominator: 1)
        XCTAssertEqual(result.label, "2\"")
    }

    func testReverse_decimalSeconds_3_10() {
        let result = appShutterSpeed(fromNumerator: 3, denominator: 10)
        XCTAssertEqual(result.label, "0.3\"")
    }

    func testReverse_halfSecond() {
        let result = appShutterSpeed(fromNumerator: 1, denominator: 2)
        XCTAssertEqual(result.label, "1/2")
    }

    func testReverse_slightlyOff_snapsToNearest() {
        // Camera reports 1/126 instead of 1/125
        let result = appShutterSpeed(fromNumerator: 1, denominator: 126)
        XCTAssertEqual(result.label, "1/125")
    }

    func testReverse_30seconds() {
        let result = appShutterSpeed(fromNumerator: 30, denominator: 1)
        XCTAssertEqual(result.label, "30\"")
    }

    // MARK: - Round-Trip: All 55 Speeds

    func testRoundTrip_allSpeeds() {
        for speed in speeds {
            let components = shutterspeedComponents(from: speed)
            let roundTripped = appShutterSpeed(
                fromNumerator: components.numerator,
                denominator: components.denominator
            )
            XCTAssertEqual(
                roundTripped.index, speed.index,
                "Round-trip failed for \(speed.label): "
                + "components=(\(components.numerator)/\(components.denominator)), "
                + "got back \(roundTripped.label)"
            )
        }
    }

    func testRoundTrip_componentsProduceCorrectSeconds() {
        for speed in speeds {
            let components = shutterspeedComponents(from: speed)
            let computedSeconds = components.numerator / components.denominator
            XCTAssertEqual(
                computedSeconds, speed.seconds, accuracy: 0.001,
                "Components seconds mismatch for \(speed.label): "
                + "expected \(speed.seconds), got \(computedSeconds)"
            )
        }
    }

    // MARK: - validateSpeeds: All Available

    func testValidate_allAvailable() {
        let set1 = [speed("1/125"), speed("1/100"), speed("1/80")]
        let result = validateSpeeds(sets: [set1], available: speeds)
        XCTAssertTrue(result.allAvailable)
        XCTAssertTrue(result.substitutions.isEmpty)
    }

    func testValidate_multipleSet_allAvailable() {
        let set1 = [speed("1/125"), speed("1/100"), speed("1/80")]
        let set2 = [speed("1/60"), speed("1/50"), speed("1/40")]
        let result = validateSpeeds(sets: [set1, set2], available: speeds)
        XCTAssertTrue(result.allAvailable)
        XCTAssertTrue(result.substitutions.isEmpty)
    }

    // MARK: - validateSpeeds: Some Missing

    func testValidate_someMissing_findsSubstitutes() {
        // Available speeds: only even-indexed
        let available = speeds.enumerated().compactMap { $0.offset.isMultiple(of: 2) ? $0.element : nil }
        // Request odd-indexed speed: "1/6400" (index 1, not in available)
        let set1 = [speeds[1]]
        let result = validateSpeeds(sets: [set1], available: available)
        XCTAssertFalse(result.allAvailable)
        XCTAssertEqual(result.substitutions.count, 1)
        XCTAssertEqual(result.substitutions[0].original.index, 1)
        // Nearest even-indexed should be 0 ("1/8000") or 2 ("1/5000")
        XCTAssertTrue(
            result.substitutions[0].substitute.index == 0
            || result.substitutions[0].substitute.index == 2
        )
    }

    func testValidate_multipleMissing() {
        // Only provide a small subset of speeds
        let available = [speeds[0], speeds[10], speeds[20], speeds[30], speeds[40], speeds[50]]
        let set1 = [speeds[5], speeds[15], speeds[25]]
        let result = validateSpeeds(sets: [set1], available: available)
        XCTAssertFalse(result.allAvailable)
        XCTAssertEqual(result.substitutions.count, 3)
    }

    // MARK: - validateSpeeds: Deduplication

    func testValidate_duplicateAcrossSets_reportedOnce() {
        let available = [speeds[0], speeds[10], speeds[20]]
        let missing = speeds[5]
        let set1 = [missing]
        let set2 = [missing]
        let result = validateSpeeds(sets: [set1, set2], available: available)
        XCTAssertFalse(result.allAvailable)
        XCTAssertEqual(result.substitutions.count, 1)
    }

    // MARK: - validateSpeeds: Empty Available

    func testValidate_emptyAvailable() {
        let set1 = [speed("1/125")]
        let result = validateSpeeds(sets: [set1], available: [])
        XCTAssertFalse(result.allAvailable)
        XCTAssertTrue(result.substitutions.isEmpty)
    }

    // MARK: - validateSpeeds: Empty Sets

    func testValidate_emptySets() {
        let result = validateSpeeds(sets: [], available: speeds)
        XCTAssertTrue(result.allAvailable)
        XCTAssertTrue(result.substitutions.isEmpty)
    }

    // MARK: - validateSpeeds: Substitution Picks Nearest

    func testValidate_substitutionPicksNearest() {
        // Available: 1/1000 (index 9) and 1/500 (index 12)
        let available = [speed("1/1000"), speed("1/500")]
        // Request: 1/800 (index 10), should pick 1/1000 (closer in seconds)
        let set1 = [speed("1/800")]
        let result = validateSpeeds(sets: [set1], available: available)
        XCTAssertEqual(result.substitutions.count, 1)
        XCTAssertEqual(result.substitutions[0].original.label, "1/800")
        XCTAssertEqual(result.substitutions[0].substitute.label, "1/1000")
    }
}
