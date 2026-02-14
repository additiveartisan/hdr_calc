<svelte:head>
	<title>Privacy Policy - HDR Calc</title>
</svelte:head>

<main>
	<div class="content">
		<h1 class="title">Privacy Policy</h1>
		<p class="updated">Last updated: February 14, 2026</p>

		<p>HDR Calc does not collect, store, or transmit any personal data.</p>

		<h2>Camera Access</h2>
		<p>The app requests camera permission solely to meter exposure from the scene for shutter speed selection. Camera frames are processed on-device in real time and are never recorded, stored, or transmitted. No photos or video are captured or saved.</p>

		<h2>Analytics</h2>
		<p>None. The app contains no analytics, tracking, or crash reporting frameworks.</p>

		<h2>Third-Party Services</h2>
		<p>None. The app makes no network requests.</p>

		<h2>Data Storage</h2>
		<p>All settings exist only in local app memory for the duration of the session. Nothing is written to disk or synced.</p>

		<h2>Contact</h2>
		<p>If you have questions about this policy, open an issue at <a href="https://github.com/additiveartisan/hdr_calc/issues">github.com/additiveartisan/hdr_calc</a>.</p>
	</div>
</main>

<style>
	main {
		max-width: 640px;
		margin: 0 auto;
		padding: var(--page-padding);
		min-height: 100dvh;
	}

	.content {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.title {
		font-weight: 600;
		font-size: 20px;
	}

	.updated {
		font-size: 13px;
		color: var(--text-muted);
	}

	h2 {
		font-weight: 600;
		font-size: 15px;
		margin-top: 8px;
	}

	p {
		font-size: 15px;
		line-height: 1.6;
	}

	a {
		color: var(--accent);
		text-decoration: none;
	}

	a:hover {
		text-decoration: underline;
	}
</style>
