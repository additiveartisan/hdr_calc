import { SPEEDS, type Speed } from './speeds';

export interface CalculationResult {
	rangeEv: number;
	sets: Speed[][];
	totalExposures: number;
}

function buildSet(start: number, frames: number, step: number): number[] {
	const indices = [start];
	let current = start;
	for (let f = 1; f < frames; f++) {
		current = Math.ceil(current + step);
		current = Math.min(current, SPEEDS.length - 1);
		indices.push(current);
	}
	return indices;
}

export function calculate(
	shadowIndex: number,
	highlightIndex: number,
	frames: number,
	spacing: number
): CalculationResult {
	const bright = Math.min(shadowIndex, highlightIndex);
	const dark = Math.max(shadowIndex, highlightIndex);
	const rangeEv = (dark - bright) / 3;

	if (rangeEv <= 0) {
		return { rangeEv: 0, sets: [], totalExposures: 1 };
	}

	const step = spacing * 3;
	const coverage = (frames - 1) * spacing;
	const sets: Speed[][] = [];
	let setStart = bright;

	if (rangeEv <= coverage) {
		const indices = buildSet(setStart, frames, step);
		sets.push(indices.map((i) => SPEEDS[i]));
	} else {
		for (let safety = 0; safety < 50; safety++) {
			const indices = buildSet(setStart, frames, step);
			sets.push(indices.map((i) => SPEEDS[i]));
			const lastFrame = indices[indices.length - 1];
			if (lastFrame > dark) break;
			setStart = lastFrame;
		}
	}

	return {
		rangeEv,
		sets,
		totalExposures: sets.length * frames
	};
}
