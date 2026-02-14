import { describe, it, expect } from 'vitest';
import { SPEEDS, labelToIndex, indexToSpeed, type Speed } from './speeds';

describe('SPEEDS table', () => {
	it('has exactly 55 entries', () => {
		expect(SPEEDS).toHaveLength(55);
	});

	it('starts with 1/8000 at index 0', () => {
		expect(SPEEDS[0].label).toBe('1/8000');
		expect(SPEEDS[0].index).toBe(0);
	});

	it('ends with 30" at the last index', () => {
		const last = SPEEDS[SPEEDS.length - 1];
		expect(last.label).toBe('30"');
		expect(last.index).toBe(54);
	});

	it('has monotonically increasing seconds values', () => {
		for (let i = 1; i < SPEEDS.length; i++) {
			expect(SPEEDS[i].seconds).toBeGreaterThan(SPEEDS[i - 1].seconds);
		}
	});

	it('has each adjacent pair differing by ~1/3 EV (nominal camera tolerance)', () => {
		for (let i = 1; i < SPEEDS.length; i++) {
			const evDiff = SPEEDS[i - 1].ev - SPEEDS[i].ev;
			expect(evDiff).toBeGreaterThan(0.2);
			expect(evDiff).toBeLessThan(0.5);
		}
	});

	it('has EV values matching log2(1/seconds)', () => {
		for (const speed of SPEEDS) {
			const expected = Math.log2(1 / speed.seconds);
			expect(speed.ev).toBeCloseTo(expected, 4);
		}
	});

	it('has sequential index values', () => {
		for (let i = 0; i < SPEEDS.length; i++) {
			expect(SPEEDS[i].index).toBe(i);
		}
	});
});

describe('labelToIndex', () => {
	it('returns 18 for 1/125', () => {
		expect(labelToIndex('1/125')).toBe(18);
	});

	it('returns 0 for 1/8000', () => {
		expect(labelToIndex('1/8000')).toBe(0);
	});

	it('returns 54 for 30"', () => {
		expect(labelToIndex('30"')).toBe(54);
	});

	it('returns 33 for 1/4', () => {
		expect(labelToIndex('1/4')).toBe(33);
	});

	it('returns 36 for 1/2', () => {
		expect(labelToIndex('1/2')).toBe(36);
	});

	it('returns 39 for 1"', () => {
		expect(labelToIndex('1"')).toBe(39);
	});

	it('returns -1 for unknown labels', () => {
		expect(labelToIndex('bogus')).toBe(-1);
	});
});

describe('indexToSpeed', () => {
	it('returns correct speed for index 33', () => {
		const speed = indexToSpeed(33);
		expect(speed).toEqual({
			index: 33,
			label: '1/4',
			seconds: 0.25,
			ev: expect.closeTo(2, 4)
		});
	});

	it('returns correct speed for index 0', () => {
		const speed = indexToSpeed(0);
		expect(speed.label).toBe('1/8000');
		expect(speed.seconds).toBeCloseTo(1 / 8000, 6);
	});

	it('returns correct speed for index 54', () => {
		const speed = indexToSpeed(54);
		expect(speed.label).toBe('30"');
		expect(speed.seconds).toBe(30);
	});
});
