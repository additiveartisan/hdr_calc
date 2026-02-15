<script lang="ts">
	interface Props {
		options: { label: string; value: number }[];
		value: number;
		ariaLabel: string;
		onchange: (value: number) => void;
	}

	let { options, value, ariaLabel, onchange }: Props = $props();

	let selectedIdx = $derived(options.findIndex((o) => o.value === value));
	let containerEl: HTMLDivElement | undefined = $state();
	let pillLeft = $state(0);
	let pillWidth = $state(0);
	let moving = $state(false);

	$effect(() => {
		if (!containerEl || selectedIdx < 0) return;
		const buttons = containerEl.querySelectorAll('button');
		const btn = buttons[selectedIdx] as HTMLElement | undefined;
		if (!btn) return;
		const newLeft = btn.offsetLeft;
		if (pillLeft !== 0 && newLeft !== pillLeft) {
			moving = true;
		}
		pillLeft = newLeft;
		pillWidth = btn.offsetWidth;
	});

	function handleKeydown(e: KeyboardEvent) {
		const idx = options.findIndex((o) => o.value === value);
		if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
			e.preventDefault();
			const next = Math.min(idx + 1, options.length - 1);
			onchange(options[next].value);
		} else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
			e.preventDefault();
			const prev = Math.max(idx - 1, 0);
			onchange(options[prev].value);
		}
	}
</script>

<!-- svelte-ignore a11y_interactive_supports_focus -->
<div
	class="segmented"
	role="radiogroup"
	aria-label={ariaLabel}
	onkeydown={handleKeydown}
	bind:this={containerEl}
>
	<div
		class="pill"
		class:moving
		style:left="{pillLeft}px"
		style:width="{pillWidth}px"
		ontransitionend={(e) => { if (e.propertyName === 'left') moving = false; }}
	></div>
	{#each options as opt}
		<button
			type="button"
			role="radio"
			aria-checked={opt.value === value}
			class:selected={opt.value === value}
			onclick={() => onchange(opt.value)}
		>
			{opt.label}
		</button>
	{/each}
</div>

<style>
	.segmented {
		display: flex;
		position: relative;
		background: var(--card);
		border: 1px solid var(--card-border);
		border-radius: 20px;
		padding: 2px;
		gap: 0px;
		overflow: hidden;
	}

	.pill {
		position: absolute;
		top: 2px;
		bottom: 2px;
		border-radius: 18px;
		background: var(--pill);
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15), 0 0 1px rgba(0, 0, 0, 0.1);
		-webkit-backdrop-filter: blur(20px);
		backdrop-filter: blur(20px);
		transition:
			left 300ms cubic-bezier(0.2, 0.8, 0.3, 1.2),
			width 300ms cubic-bezier(0.2, 0.8, 0.3, 1.2),
			background 0ms,
			transform 300ms cubic-bezier(0.2, 0.8, 0.3, 1.2);
		pointer-events: none;
	}

	.pill.moving {
		background: var(--pill-glass);
		transform: scale(1.06);
	}

	@media (prefers-reduced-motion: reduce) {
		.pill {
			transition: none;
		}
	}

	button {
		flex: 1;
		position: relative;
		z-index: 1;
		border: none;
		background: none;
		font-family: inherit;
		font-weight: 500;
		font-size: 14px;
		padding: 7px 10px;
		cursor: pointer;
		color: var(--text-muted);
		border-radius: 16px;
		transition: color 150ms ease;
	}

	button.selected {
		color: var(--text);
	}

	button:focus-visible {
		outline: 2px solid var(--accent);
		outline-offset: 2px;
	}
</style>
