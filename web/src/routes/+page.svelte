<script lang="ts">
	import { calculate } from '$lib/calculator';
	import { SPEEDS, labelToIndex } from '$lib/speeds';
	import SpeedPicker from '$lib/components/SpeedPicker.svelte';
	import SegmentedControl from '$lib/components/SegmentedControl.svelte';


	let shadowIndex = $state(labelToIndex('1/4'));
	let highlightIndex = $state(labelToIndex('1/1000'));
	let frames = $state(5);
	let spacing = $state(2);


	let result = $derived(calculate(shadowIndex, highlightIndex, frames, spacing));

	const frameOptions = [
		{ label: '3', value: 3 },
		{ label: '5', value: 5 },
		{ label: '7', value: 7 },
		{ label: '9', value: 9 }
	];

	const spacingOptions = [
		{ label: '1', value: 1 },
		{ label: '1.5', value: 1.5 },
		{ label: '2', value: 2 }
	];

	function setColor(i: number): string {
		return i % 2 === 0 ? 'var(--bracket-1)' : 'var(--bracket-2)';
	}

	function centerIndex(setLength: number): number {
		return Math.floor(setLength / 2);
	}

	let showHelp = $state(false);
</script>

<main>
	<div class="layout">
		<div class="inputs">
			<h1 class="title">
				HDR Calc
				<span class="title-rule"></span>
				<button class="help-btn" aria-label="How to use" onclick={() => showHelp = true}>?</button>
			</h1>

			<SpeedPicker
				label="Shadows"
				value={shadowIndex}
				onchange={(v) => (shadowIndex = v)}
			/>

			<div style="height: var(--card-gap)"></div>

			<SpeedPicker
				label="Highlights"
				value={highlightIndex}
				onchange={(v) => (highlightIndex = v)}
			/>

			<div style="height: var(--section-gap)"></div>

			<div class="label">AEB Frames</div>
			<SegmentedControl
				options={frameOptions}
				value={frames}
				ariaLabel="Frames per AEB set"
				onchange={(v) => (frames = v)}
			/>

			<div style="height: var(--card-gap)"></div>

			<div class="label">EV Spacing</div>
			<SegmentedControl
				options={spacingOptions}
				value={spacing}
				ariaLabel="EV spacing between frames"
				onchange={(v) => (spacing = v)}
			/>
		</div>

		<div class="results">
			<div class="range-stat">
				<span class="range-number">{Math.round(result.rangeEv * 10) / 10}</span>
				<span class="range-unit">EV</span>
			</div>
			<div class="range-label">Scene Dynamic Range</div>

			{#if result.rangeEv === 0}
				<p class="message">Single exposure needed. No bracketing required.</p>
			{:else}
				<div class="summary">
					<span class="summary-item">{result.sets.length} set{result.sets.length > 1 ? 's' : ''}</span>
					<span class="summary-sep">&middot;</span>
					<span class="summary-item">{result.totalExposures} exposures</span>
				</div>

				<div style="height: var(--section-gap)"></div>

				{#each result.sets as set, i}
					<div
						class="set-group"
						role="group"
						aria-label="Set {i + 1}"
					>
						<div class="set-header">
							<span class="set-dot" style:background={setColor(i)}></span>
							Set {i + 1}
						</div>
						<div class="speed-ruler">
							<div class="ruler-track" style:background={setColor(i)}></div>
							{#each set as speed, j}
								{@const pct = set.length > 1 ? (j / (set.length - 1)) * 100 : 50}
								{@const isCenter = j === centerIndex(set.length)}
								<div class="ruler-tick" style:left="{pct}%">
									<div class="tick-mark" class:center={isCenter} style:background={isCenter ? 'var(--accent)' : 'var(--text-muted)'}></div>
									<span class="tick-speed" class:center={isCenter}>{speed.label}</span>
								</div>
							{/each}
						</div>
					</div>
				{/each}
			{/if}
		</div>
	</div>

	<footer>
		<span>&copy; 2026 HDR Calc</span>
		<span class="footer-sep">&middot;</span>
		<a href="/privacy">Privacy</a>
	</footer>
</main>

{#if showHelp}
<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div class="overlay" role="dialog" aria-label="How to use HDR Calc" onclick={() => showHelp = false} onkeydown={(e) => e.key === 'Escape' && (showHelp = false)}>
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal" onclick={(e) => e.stopPropagation()} onkeydown={() => {}}>
		<div class="modal-header">
			<span class="modal-title">How to Use</span>
			<button class="modal-close" aria-label="Close" onclick={() => showHelp = false}>&times;</button>
		</div>
		<ol class="steps">
			<li><strong>Meter your shadows.</strong> Point your camera at the darkest area you want detail in and note the shutter speed. Set it under Shadows.</li>
			<li><strong>Meter your highlights.</strong> Point at the brightest area and note that shutter speed. Set it under Highlights.</li>
			<li><strong>Match your camera's AEB settings.</strong> Set AEB Frames and EV Spacing to match what your camera supports.</li>
			<li><strong>Read the results.</strong> The calculator shows how many bracket sets you need and the center shutter speed for each set.</li>
		</ol>
	</div>
</div>
{/if}

<style>
	main {
		max-width: 960px;
		margin: 0 auto;
		padding: var(--page-padding);
		min-height: 100dvh;
	}

	.layout {
		display: flex;
		flex-direction: column;
		gap: var(--section-gap);
	}

	@media (min-width: 769px) {
		.layout {
			max-width: 480px;
			margin: 0 auto;
		}
	}

	.title {
		font-weight: 600;
		font-size: 20px;
		margin-bottom: var(--section-gap);
		display: flex;
		align-items: center;
		gap: 16px;
	}

	.title-rule {
		flex: 1;
		height: 1px;
		background: var(--card-border);
	}

	.help-btn {
		width: 24px;
		height: 24px;
		border-radius: 50%;
		border: 1px solid var(--card-border);
		background: transparent;
		color: var(--text-muted);
		font-family: inherit;
		font-size: 13px;
		font-weight: 500;
		line-height: 1;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		transition: color 0.15s, border-color 0.15s;
	}

	.help-btn:hover {
		color: var(--text);
		border-color: var(--text-muted);
	}

	.range-stat {
		display: flex;
		align-items: baseline;
		gap: 6px;
	}

	.range-stat::after {
		content: '';
		flex: 1;
		height: 1px;
		background: var(--card-border);
		align-self: center;
	}

	.range-number {
		font-weight: 600;
		font-size: 20px;
		line-height: 1;
	}

	.range-unit {
		font-weight: 600;
		font-size: 20px;
		color: var(--text);
	}

	.range-label {
		font-weight: 500;
		font-size: 13px;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--text-muted);
		margin-top: var(--section-gap);
	}

	.message {
		color: var(--text-muted);
		font-size: 15px;
		margin-top: 16px;
	}

	.summary {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-top: 8px;
		font-size: 15px;
		color: var(--text-muted);
	}

	.summary-sep {
		opacity: 0.4;
	}

	.set-group {
		margin-bottom: 16px;
		padding: 20px var(--card-padding) 14px;
		border-radius: var(--card-radius);
		background: var(--card);
	}

.set-header {
		display: flex;
		align-items: center;
		gap: 8px;
		font-weight: 500;
		font-size: 13px;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--text-muted);
		margin-bottom: 8px;
	}

	.set-dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.speed-ruler {
		position: relative;
		height: 48px;
		margin: 0 24px;
	}

	.ruler-track {
		position: absolute;
		top: 10px;
		left: 0;
		right: 0;
		height: 2px;
		opacity: 0.3;
		border-radius: 1px;
	}

	.ruler-tick {
		position: absolute;
		top: 0;
		transform: translateX(-50%);
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	.tick-mark {
		width: 2px;
		height: 12px;
		border-radius: 1px;
		opacity: 0.5;
	}

	.tick-mark.center {
		width: 3px;
		height: 16px;
		opacity: 1;
	}

	.tick-speed {
		margin-top: 4px;
		font-size: 11px;
		font-weight: 400;
		color: var(--text-muted);
		white-space: nowrap;
	}

	.tick-speed.center {
		font-weight: 600;
		font-size: 13px;
		color: var(--accent);
	}

	footer {
		margin-top: 0;
		padding: 16px 0;
		text-align: center;
	}

	footer span {
		font-size: 12px;
		color: var(--text-muted);
	}

	.footer-sep {
		opacity: 0.4;
	}

	footer a {
		font-size: 12px;
		color: var(--text-muted);
		text-decoration: none;
		letter-spacing: 0.03em;
	}

	footer a:hover {
		color: var(--text);
	}

	.overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 100;
		padding: var(--page-padding);
	}

	.modal {
		background: var(--bg);
		border: 1px solid var(--card-border);
		border-radius: var(--card-radius);
		max-width: 420px;
		width: 100%;
		padding: 24px;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 20px;
	}

	.modal-title {
		font-weight: 600;
		font-size: 17px;
	}

	.modal-close {
		background: none;
		border: none;
		color: var(--text-muted);
		font-size: 22px;
		cursor: pointer;
		line-height: 1;
		padding: 0 4px;
	}

	.modal-close:hover {
		color: var(--text);
	}

	.steps {
		list-style: none;
		counter-reset: step;
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.steps li {
		counter-increment: step;
		font-size: 14px;
		line-height: 1.5;
		color: var(--text);
		padding-left: 32px;
		position: relative;
	}

	.steps li::before {
		content: counter(step);
		position: absolute;
		left: 0;
		top: 0;
		width: 22px;
		height: 22px;
		border-radius: 50%;
		background: var(--accent-soft);
		color: var(--accent);
		font-weight: 600;
		font-size: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

</style>
