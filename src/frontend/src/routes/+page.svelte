<!-- src/routes/+page.svelte -->
<script>
	let darkMode = true; // toggle this to test light/dark
	let activeNotebook = 'Untitled Notebook';
</script>

<svelte:head>
	<title>{activeNotebook} – Zenji Notebook</title>
</svelte:head>

<div class="app" class:dark={darkMode}>
	<!-- Top bar -->
	<header class="topbar">
		<div class="logo">Zenji</div>
		<div class="notebook-title">
			<input type="text" bind:value={activeNotebook} placeholder="Untitled Notebook" />
		</div>
		<div class="actions">
			<button>Kernel: Idle ▼</button>
			<button>Restart</button>
			<button>Interrupt</button>
			<button on:click={() => (darkMode = !darkMode)}>Toggle Theme</button>
		</div>
	</header>

	<!-- Main layout: sidebar + editor area -->
	<div class="main">
		<!-- Left sidebar (file tree / sessions placeholder) -->
		<aside class="sidebar">
			<h3>Notebooks</h3>
			<ul>
				<li class="active">My First Notebook</li>
				<li>Analysis 2026</li>
				<li>Experiments</li>
			</ul>

			<h3>Sessions</h3>
			<ul>
				<li>Python 3 (idle)</li>
				<li>R session</li>
			</ul>

			<button class="new">+ New Notebook</button>
		</aside>

		<!-- Main notebook content area -->
		<main class="notebook">
			<!-- Toolbar above cells -->
			<div class="cell-toolbar">
				<button>+ Code</button>
				<button>+ Markdown</button>
				<button>Run All</button>
			</div>

			<!-- Example cells -->
			<div class="cell code">
				<div class="cell-gutter">In [1]</div>
				<div class="cell-editor">
					<pre><code
							># Simple example
print("Hello from future notebook")
import numpy as np
np.random.rand(5)</code
						></pre>
				</div>
				<div class="cell-run">▶</div>
			</div>

			<div class="cell output">
				<div class="cell-gutter">Out [1]</div>
				<pre class="output-text">Hello from future notebook
array([0.42, 0.72, 0.0001, 0.3, 0.15])</pre>
			</div>

			<div class="cell markdown">
				<div class="cell-gutter"></div>
				<div class="cell-editor">
					<h1>Welcome to Zenji</h1>
					<p>
						This is a markdown cell. You can write **bold**, *italic*, lists, LaTeX $E=mc^2$, etc.
					</p>
				</div>
			</div>

			<!-- Empty cell placeholder -->
			<div class="cell empty">
				<div class="cell-gutter">+</div>
				<div class="cell-editor placeholder">Click to add code or markdown…</div>
			</div>
		</main>
	</div>
</div>

<style>
	:global(:root) {
		--bg: #ffffff;
		--text: #1a1a1a;
		--sidebar-bg: #f8f9fa;
		--cell-bg: #fff;
		--border: #e0e0e0;
	}
	:global(.dark) {
		--bg: #121212;
		--text: #e0e0e0;
		--sidebar-bg: #1e1e1e;
		--cell-bg: #1e1e1e;
		--border: #333;
	}

	.app {
		height: 100vh;
		display: flex;
		flex-direction: column;
		background: var(--bg);
		color: var(--text);
		font-family: system-ui, sans-serif;
	}

	.topbar {
		height: 48px;
		background: var(--sidebar-bg);
		border-bottom: 1px solid var(--border);
		display: flex;
		align-items: center;
		padding: 0 1rem;
		gap: 1rem;
	}
	.logo {
		font-weight: bold;
		font-size: 1.2rem;
	}
	.notebook-title input {
		background: transparent;
		border: none;
		font-size: 1.1rem;
		flex: 1;
		color: inherit;
	}
	.actions {
		display: flex;
		gap: 0.5rem;
	}
	.actions button {
		background: var(--border);
		border: none;
		padding: 0.4rem 0.8rem;
		border-radius: 4px;
		cursor: pointer;
	}

	.main {
		flex: 1;
		display: flex;
		overflow: hidden;
	}

	.sidebar {
		width: 240px;
		background: var(--sidebar-bg);
		border-right: 1px solid var(--border);
		padding: 1rem;
		overflow-y: auto;
	}
	.sidebar h3 {
		margin: 1.5rem 0 0.5rem;
		font-size: 0.9rem;
		color: gray;
	}
	.sidebar ul {
		list-style: none;
		padding: 0;
		margin: 0;
	}
	.sidebar li {
		padding: 0.5rem;
		cursor: pointer;
		border-radius: 4px;
	}
	.sidebar li:hover,
	.sidebar li.active {
		background: rgba(100, 100, 100, 0.1);
	}
	.new {
		margin-top: 1rem;
		width: 100%;
		padding: 0.6rem;
		background: #0066cc;
		color: white;
		border: none;
		border-radius: 4px;
	}

	.notebook {
		flex: 1;
		padding: 1rem;
		overflow-y: auto;
	}
	.cell-toolbar {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}
	.cell {
		margin-bottom: 1.5rem;
		border: 1px solid var(--border);
		border-radius: 6px;
		background: var(--cell-bg);
		position: relative;
	}
	.cell-gutter {
		position: absolute;
		left: -60px;
		top: 8px;
		color: gray;
		font-size: 0.85rem;
		width: 50px;
		text-align: right;
	}
	.cell-editor {
		padding: 1rem;
		font-family: 'SF Mono', 'Consolas', monospace;
		white-space: pre-wrap;
	}
	.cell.code .cell-editor {
		background: rgba(0, 0, 0, 0.03);
		border-radius: 4px;
	}
	.output-text {
		background: rgba(0, 100, 0, 0.08);
		padding: 1rem;
		border-radius: 4px;
	}
	.placeholder {
		color: gray;
		font-style: italic;
	}

	.cell-run {
		position: absolute;
		right: 8px;
		top: 8px;
		font-size: 1.2rem;
		color: #0066cc;
		cursor: pointer;
	}
</style>
