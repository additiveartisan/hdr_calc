<script lang="ts">
	import '../app.css';

	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href="/favicon.svg" />
	<link rel="manifest" href="/manifest.json" />
	<link rel="preload" href="/fonts/outfit.woff2" as="font" type="font/woff2" crossorigin="anonymous" />
	<meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)" />
	<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
	<title>HDR Calc</title>
</svelte:head>

{@render children()}
