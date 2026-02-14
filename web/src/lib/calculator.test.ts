import { describe, it, expect } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import { calculate, type CalculationResult } from './calculator';
import { labelToIndex } from './speeds';

interface TestVector {
	name: string;
	input: {
		shadow: string;
		highlight: string;
		frames: number;
		spacing: number;
	};
	expected: {
		rangeEv: number;
		numSets: number;
		totalExposures: number;
		sets: string[][];
	};
}

const vectorsPath = resolve(__dirname, '../../../test_vectors.json');
const vectors: TestVector[] = JSON.parse(readFileSync(vectorsPath, 'utf-8')).vectors;

function runVector(vector: TestVector) {
	const shadowIndex = labelToIndex(vector.input.shadow);
	const highlightIndex = labelToIndex(vector.input.highlight);
	expect(shadowIndex).not.toBe(-1);
	expect(highlightIndex).not.toBe(-1);

	const result = calculate(
		shadowIndex,
		highlightIndex,
		vector.input.frames,
		vector.input.spacing
	);

	expect(result.rangeEv).toBe(vector.expected.rangeEv);
	expect(result.sets.length).toBe(vector.expected.numSets);
	expect(result.totalExposures).toBe(vector.expected.totalExposures);

	for (let s = 0; s < vector.expected.sets.length; s++) {
		const expectedLabels = vector.expected.sets[s];
		const actualLabels = result.sets[s].map((speed) => speed.label);
		expect(actualLabels).toEqual(expectedLabels);
	}
}

describe('calculator', () => {
	for (const vector of vectors) {
		it(`Vector: ${vector.name}`, () => {
			runVector(vector);
		});
	}

	it('swaps inverted inputs (shadow brighter than highlight)', () => {
		const normal = calculate(
			labelToIndex('1/4'),
			labelToIndex('1/1000'),
			5,
			1
		);
		const inverted = calculate(
			labelToIndex('1/1000'),
			labelToIndex('1/4'),
			5,
			1
		);
		expect(inverted.rangeEv).toBe(normal.rangeEv);
		expect(inverted.sets.length).toBe(normal.sets.length);
		expect(inverted.totalExposures).toBe(normal.totalExposures);
	});

	it('clamps frame indices to table bounds', () => {
		const result = calculate(
			labelToIndex('30"'),
			labelToIndex('15"'),
			5,
			2
		);
		expect(result.sets.length).toBeGreaterThanOrEqual(1);
		for (const set of result.sets) {
			for (const speed of set) {
				expect(speed.index).toBeGreaterThanOrEqual(0);
				expect(speed.index).toBeLessThanOrEqual(54);
			}
		}
	});
});
