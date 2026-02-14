<script lang="ts">
	import { SPEEDS, type Speed } from '$lib/speeds';

	interface Props {
		label: string;
		value: number;
		onchange: (index: number) => void;
	}

	let { label, value, onchange }: Props = $props();

	let open = $state(false);
	let listEl: HTMLDivElement | undefined = $state();
	let triggerEl: HTMLButtonElement | undefined = $state();

	let currentSpeed = $derived(SPEEDS[value]);

	function toggle() {
		open = !open;
		if (open) {
			requestAnimationFrame(() => {
				const active = listEl?.querySelector('[aria-selected="true"]');
				active?.scrollIntoView({ block: 'center' });
			});
		}
	}

	function select(index: number) {
		onchange(index);
		open = false;
		triggerEl?.focus();
	}

	function handleKeydown(e: KeyboardEvent) {
		if (!open) {
			if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
				e.preventDefault();
				toggle();
			}
			return;
		}

		if (e.key === 'Escape') {
			e.preventDefault();
			open = false;
			triggerEl?.focus();
		} else if (e.key === 'ArrowDown') {
			e.preventDefault();
			const next = Math.min(value + 1, SPEEDS.length - 1);
			onchange(next);
			scrollToActive();
		} else if (e.key === 'ArrowUp') {
			e.preventDefault();
			const prev = Math.max(value - 1, 0);
			onchange(prev);
			scrollToActive();
		} else if (e.key === 'Enter') {
			e.preventDefault();
			open = false;
			triggerEl?.focus();
		}
	}

	function scrollToActive() {
		requestAnimationFrame(() => {
			const active = listEl?.querySelector('[aria-selected="true"]');
			active?.scrollIntoView({ block: 'nearest' });
		});
	}

	function handleClickOutside(e: MouseEvent) {
		if (open && triggerEl && !triggerEl.closest('.picker')?.contains(e.target as Node)) {
			open = false;
		}
	}
</script>

<svelte:window onclick={handleClickOutside} />

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div class="picker" role="group" onkeydown={handleKeydown}>
	<div class="label">{label}</div>
	<button
		type="button"
		class="trigger"
		bind:this={triggerEl}
		onclick={toggle}
		aria-expanded={open}
		aria-haspopup="listbox"
	>
		<span class="speed-value">{currentSpeed.label}</span>
		<span class="chevron" class:open>&#x25BE;</span>
	</button>

	{#if open}
		<div
			class="dropdown"
			role="listbox"
			tabindex="-1"
			bind:this={listEl}
			aria-activedescendant="speed-{value}"
		>
			{#each SPEEDS as speed}
				<button
					type="button"
					role="option"
					id="speed-{speed.index}"
					class="option"
					aria-selected={speed.index === value}
					class:selected={speed.index === value}
					onclick={() => select(speed.index)}
				>
					{speed.label}
				</button>
			{/each}
		</div>
	{/if}
</div>

<style>
	.picker {
		position: relative;
	}

	.label {
		font-weight: 500;
		font-size: 13px;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--text-muted);
		margin-bottom: 8px;
	}

	.trigger {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		padding: 8px 12px;
		background: var(--card);
		border: 1px solid var(--card-border);
		border-radius: var(--control-radius);
		font-family: inherit;
		cursor: pointer;
		color: var(--text);
	}

	.trigger:focus-visible {
		outline: 2px solid var(--accent);
		outline-offset: 2px;
	}

	.speed-value {
		font-weight: 500;
		font-size: 15px;
	}

	.chevron {
		font-size: 14px;
		color: var(--text-muted);
		transition: transform 200ms ease;
	}

	.chevron.open {
		transform: rotate(180deg);
	}

	.dropdown {
		position: absolute;
		top: calc(100% + 4px);
		left: 0;
		right: 0;
		max-height: 280px;
		overflow-y: auto;
		background: var(--card);
		border: 1px solid var(--card-border);
		border-radius: var(--card-radius);
		z-index: 10;
		overscroll-behavior: contain;
	}

	.option {
		display: block;
		width: 100%;
		padding: 10px var(--card-padding);
		background: none;
		border: none;
		font-family: inherit;
		font-size: 15px;
		font-weight: 400;
		color: var(--text);
		text-align: left;
		cursor: pointer;
	}

	.option:hover {
		background: var(--accent-soft);
	}

	.option.selected {
		font-weight: 500;
		color: var(--accent);
	}
</style>
