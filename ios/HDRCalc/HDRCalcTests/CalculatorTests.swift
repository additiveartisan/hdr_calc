import XCTest
@testable import HDRCalc

final class CalculatorTests: XCTestCase {

    // MARK: - Test Vector Structures

    private struct TestVector: Decodable {
        let name: String
        let input: Input
        let expected: Expected

        struct Input: Decodable {
            let shadow: String
            let highlight: String
            let frames: Int
            let spacing: Double
        }

        struct Expected: Decodable {
            let rangeEv: Double
            let numSets: Int
            let totalExposures: Int
            let sets: [[String]]
        }
    }

    private struct TestVectorFile: Decodable {
        let vectors: [TestVector]
    }

    private func loadVectors() -> [TestVector] {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "test_vectors", withExtension: "json") else {
            XCTFail("test_vectors.json not found in test bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(TestVectorFile.self, from: data)
            return file.vectors
        } catch {
            XCTFail("Failed to decode test_vectors.json: \(error)")
            return []
        }
    }

    // MARK: - Data-Driven Test Vectors

    func testAllVectors() {
        let vectors = loadVectors()
        XCTAssertEqual(vectors.count, 6, "Expected 6 test vectors")

        for vector in vectors {
            let shadowIdx = labelToIndex(vector.input.shadow)
            let highlightIdx = labelToIndex(vector.input.highlight)
            XCTAssertNotEqual(shadowIdx, -1, "Unknown shadow speed: \(vector.input.shadow)")
            XCTAssertNotEqual(highlightIdx, -1, "Unknown highlight speed: \(vector.input.highlight)")

            let result = calculate(
                shadowIndex: shadowIdx,
                highlightIndex: highlightIdx,
                frames: vector.input.frames,
                spacing: vector.input.spacing
            )

            XCTAssertEqual(
                result.rangeEv, vector.expected.rangeEv,
                accuracy: 0.1,
                "\(vector.name): rangeEv mismatch"
            )
            XCTAssertEqual(
                result.sets.count, vector.expected.numSets,
                "\(vector.name): numSets mismatch"
            )
            XCTAssertEqual(
                result.totalExposures, vector.expected.totalExposures,
                "\(vector.name): totalExposures mismatch"
            )

            // Verify set contents
            XCTAssertEqual(
                result.sets.count, vector.expected.sets.count,
                "\(vector.name): set count mismatch"
            )
            for (setIdx, expectedSet) in vector.expected.sets.enumerated() {
                guard setIdx < result.sets.count else { continue }
                let actualLabels = result.sets[setIdx].map(\.label)
                XCTAssertEqual(
                    actualLabels, expectedSet,
                    "\(vector.name): Set \(setIdx + 1) labels mismatch"
                )
            }
        }
    }

    // MARK: - Edge Cases

    func testInvertedInputs() {
        // Shadow brighter than highlight: should swap silently
        let normal = calculate(shadowIndex: labelToIndex("1/4"), highlightIndex: labelToIndex("1/1000"), frames: 5, spacing: 1)
        let inverted = calculate(shadowIndex: labelToIndex("1/1000"), highlightIndex: labelToIndex("1/4"), frames: 5, spacing: 1)
        XCTAssertEqual(normal.rangeEv, inverted.rangeEv)
        XCTAssertEqual(normal.sets.count, inverted.sets.count)
        XCTAssertEqual(normal.totalExposures, inverted.totalExposures)
    }

    func testZeroRange() {
        let result = calculate(shadowIndex: labelToIndex("1/125"), highlightIndex: labelToIndex("1/125"), frames: 5, spacing: 1)
        XCTAssertEqual(result.rangeEv, 0)
        XCTAssertEqual(result.sets.count, 0)
        XCTAssertEqual(result.totalExposures, 1)
    }

    func testSingleSetCoversRange() {
        // 3 EV range with 5 frames at 1 EV spacing = 4 EV coverage, should fit in 1 set
        let result = calculate(shadowIndex: labelToIndex("1/30"), highlightIndex: labelToIndex("1/250"), frames: 5, spacing: 1)
        XCTAssertEqual(result.sets.count, 1)
    }

    func testSetOverlap() {
        // Multiple sets should share exactly one frame at the boundary
        let result = calculate(shadowIndex: labelToIndex("1/4"), highlightIndex: labelToIndex("1/1000"), frames: 5, spacing: 1)
        XCTAssertGreaterThan(result.sets.count, 1)

        for i in 1..<result.sets.count {
            let prevLast = result.sets[i - 1].last!.label
            let nextFirst = result.sets[i].first!.label
            XCTAssertEqual(prevLast, nextFirst, "Sets \(i) and \(i + 1) should overlap at one frame")
        }
    }

    func testClampingToTableBounds() {
        // When last entries extend beyond the table, should clamp
        let result = calculate(shadowIndex: 0, highlightIndex: speeds.count - 1, frames: 9, spacing: 2)
        for set in result.sets {
            for speed in set {
                XCTAssertGreaterThanOrEqual(speed.index, 0)
                XCTAssertLessThan(speed.index, speeds.count)
            }
        }
    }
}
