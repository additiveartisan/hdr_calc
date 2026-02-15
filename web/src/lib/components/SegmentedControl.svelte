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
		--spring-bouncy: linear(
			0, 0.006, 0.024 2.2%, 0.098 4.5%,
			0.284 7.7%, 0.536 11.1%, 0.776 14.3%,
			0.928 16.8%, 1.028 19%, 1.091 21%,
			1.124 22.9%, 1.135 24.7%, 1.128 26.5%,
			1.089 29.7%, 1.042 33.2%, 1.01 36.8%,
			0.99 40.1%, 0.98 43.5%, 0.978 46.7%,
			0.984 50.8%, 0.995 56.1%, 1.003 61.5%,
			1.007 67%, 1.005 73.5%, 1.002 80%,
			1 100%
		);
		transition:
			left 400ms var(--spring-bouncy),
			width 400ms var(--spring-bouncy),
			background 0ms,
			transform 400ms var(--spring-bouncy);
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
