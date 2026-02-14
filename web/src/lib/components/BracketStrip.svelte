<script lang="ts">
	import type { Speed } from '$lib/speeds';

	interface Props {
		sets: Speed[][];
		rangeEv: number;
		highlightIndex: number;
		shadowIndex: number;
		hoveredSet: number;
		onhover: (index: number) => void;
	}

	let { sets, rangeEv, highlightIndex, shadowIndex, hoveredSet, onhover }: Props = $props();

	let bright = $derived(Math.min(highlightIndex, shadowIndex));
	let dark = $derived(Math.max(highlightIndex, shadowIndex));

	let stripRange = $derived.by(() => {
		if (sets.length === 0) return { min: bright, max: dark || bright + 1 };
		let min = Infinity;
		let max = -Infinity;
		for (const set of sets) {
			for (const speed of set) {
				if (speed.index < min) min = speed.index;
				if (speed.index > max) max = speed.index;
			}
		}
		return { min, max: max || min + 1 };
	});

	let totalSpan = $derived(stripRange.max - stripRange.min || 1);
	let tickStep = $derived(totalSpan <= 18 ? 3 : 6);
	let tickCount = $derived(Math.floor(totalSpan / tickStep) + 1);

	function pct(index: number): number {
		return ((index - stripRange.min) / totalSpan) * 100;
	}

	let ariaDescription = $derived(
		sets.length === 0
			? 'Single exposure, no bracketing'
			: `Bracket visualization: ${sets.length} set${sets.length > 1 ? 's' : ''} covering ${rangeEv} EV range`
	);

	function setColor(i: number): string {
		return i % 2 === 0 ? 'var(--bracket-1)' : 'var(--bracket-2)';
	}
</script>

<div class="strip-container" role="img" aria-label={ariaDescription}>
	<div class="strip">
		{#if sets.length === 0}
			<div class="single-marker" style:left="50%"></div>
		{:else}
			{#each sets as set, i}
				{@const first = set[0].index}
				{@const last = set[set.length - 1].index}
				<!-- svelte-ignore a11y_no_static_element_interactions -->
				<div
					class="segment"
					class:hovered={hoveredSet === i}
					style:left="{pct(first)}%"
					style:width="{pct(last) - pct(first)}%"
					style:background={setColor(i)}
					onmouseenter={() => onhover(i)}
					onmouseleave={() => onhover(-1)}
				></div>
			{/each}
		{/if}
	</div>

	{#if sets.length > 0}
		<div class="ticks">
			{#each Array(tickCount) as _, i}
				{@const idx = stripRange.min + i * tickStep}
				{#if idx <= stripRange.max}
					<div class="tick" style:left="{pct(idx)}%">
						<div class="tick-line"></div>
						<span class="tick-label">{Math.round(((idx - bright) / 3) * 10) / 10}</span>
					</div>
				{/if}
			{/each}
		</div>
	{/if}
</div>

<style>
	.strip-container {
		width: 100%;
	}

	.strip {
		position: relative;
		height: 48px;
		background: var(--card);
		border: 1px solid var(--card-border);
		border-radius: var(--control-radius);
		overflow: hidden;
	}

	.segment {
		position: absolute;
		top: 0;
		bottom: 0;
		border-radius: 4px;
		opacity: 0.85;
		transition: left 300ms ease-out, width 300ms ease-out, opacity 150ms ease;
	}

	.segment.hovered {
		opacity: 1;
	}

	.segment:not(.hovered) {
		filter: saturate(1.2);
	}

	@media (prefers-reduced-motion: reduce) {
		.segment {
			transition: none;
		}
	}

	.single-marker {
		position: absolute;
		top: 50%;
		width: 8px;
		height: 8px;
		background: var(--accent);
		border-radius: 50%;
		transform: translate(-50%, -50%);
	}

	.ticks {
		position: relative;
		height: 24px;
		margin-top: 4px;
	}

	.tick {
		position: absolute;
		transform: translateX(-50%);
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	.tick-line {
		width: 1px;
		height: 6px;
		background: var(--text-muted);
		opacity: 0.4;
	}

	.tick-label {
		font-size: 10px;
		color: var(--text-muted);
		margin-top: 2px;
	}
</style>
