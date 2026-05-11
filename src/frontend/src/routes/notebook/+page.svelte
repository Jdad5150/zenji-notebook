<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { Plus, Loader2 } from '@lucide/svelte';
	import NotebookSidebar from '$lib/components/NotebookSidebar.svelte';
	import NotebookToolbar from '$lib/components/NotebookToolbar.svelte';
	import NotebookCell from '$lib/components/NotebookCell.svelte';
	import NotebookMenuBar from '$lib/components/NotebookMenuBar.svelte';
	import DataExplorer from '$lib/components/DataExplorer.svelte';

	interface OutputData {
		output_type: string;
		data: string;
	}

	interface CellData {
		id: number;
		type: 'code' | 'markdown';
		content: string;
		output: string;
		rendered: boolean;
		outputs: OutputData[];
	}

	let sidebarOpen = $state(true);
	let dataExplorerOpen = $state(true);
	let mode = $state<'edit' | 'view'>('edit');
	let notebookPath = $state('');
	let notebookTitle = $state('');
	let kernel = $state('Python');
	let runtimeStatus = $state<'idle' | 'running' | 'error'>('idle');
	let activeCellId = $state<number | null>(null);
	let varsRefreshKey = $state(0);
	let loadError = $state('');
	let loading = $state(true);

	let cells = $state<CellData[]>([]);
	let nextId = $state(0);

	const tocEntries = $derived(
		cells
			.filter((c) => c.type === 'markdown')
			.flatMap((c) =>
				c.content
					.split('\n')
					.filter((line) => line.startsWith('#'))
					.map((line) => {
						const level = line.match(/^#+/)?.[0].length ?? 1;
						const text = line.replace(/^#+\s*/, '');
						return { text, level, cellId: c.id };
					})
			)
	);

	let activeCellType = $derived(cells.find((c) => c.id === activeCellId)?.type ?? 'code');

	function outputsToString(outputs: OutputData[]): string {
		return outputs.map((o) => o.data).join('');
	}

	onMount(async () => {
		const path = page.url.searchParams.get('path');
		if (!path) {
			loadError = 'No notebook path specified.';
			loading = false;
			return;
		}
		notebookPath = path;
		notebookTitle = path.split('/').pop() ?? path;

		const res = await fetch(`/api/notebook?path=${encodeURIComponent(path)}`);
		if (!res.ok) {
			loadError = `Failed to load notebook: ${res.status}`;
			loading = false;
			return;
		}

		const nb = await res.json();
		kernel = nb.kernel_type ?? 'python';
		nextId = nb.next_cell_id ?? 0;

		cells = (nb.cells ?? []).map(
			(c: {
				cell_id: number;
				cell_type: string;
				source: string;
				execution_count: number;
				outputs: OutputData[];
			}) => ({
				id: c.cell_id,
				type: c.cell_type === 'markdown' ? 'markdown' : 'code',
				content: c.source,
				output: outputsToString(c.outputs ?? []),
				rendered: c.cell_type === 'markdown',
				outputs: c.outputs ?? []
			})
		);

		loading = false;
	});

	async function runCell(id: number) {
		const cell = cells.find((c) => c.id === id);
		if (!cell) return;

		if (cell.type === 'markdown') {
			cell.rendered = true;
			return;
		}

		await saveNotebook();

		runtimeStatus = 'running';
		const res = await fetch('/api/execute', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ path: notebookPath, cell_id: id })
		});

		if (res.ok) {
			// Re-fetch the full notebook from disk so the UI reflects reality
			const nbRes = await fetch(`/api/notebook?path=${encodeURIComponent(notebookPath)}`);
			if (nbRes.ok) {
				const nb = await nbRes.json();
				nextId = nb.next_cell_id;
				cells = nb.cells.map(
					(c: { cell_id: number; cell_type: string; source: string; outputs: OutputData[] }) => ({
						id: c.cell_id,
						type: c.cell_type === 'markdown' ? 'markdown' : 'code',
						content: c.source,
						output: outputsToString(c.outputs ?? []),
						rendered: c.cell_type === 'markdown',
						outputs: c.outputs ?? []
					})
				);
				runtimeStatus = 'idle';
				varsRefreshKey++;
			} else {
				runtimeStatus = 'error';
			}
		} else {
			runtimeStatus = 'error';
		}
		activeCellId = null;
	}

	function addCell(type: 'code' | 'markdown' = 'code', atIndex?: number) {
		const id = nextId++;
		const newCell: CellData = { id, type, content: '', output: '', rendered: false, outputs: [] };
		if (atIndex !== undefined) {
			cells = [...cells.slice(0, atIndex), newCell, ...cells.slice(atIndex)];
		} else {
			cells = [...cells, newCell];
		}
		activeCellId = id;
		saveNotebook();
	}

	function setActiveCellType() {
		const cell = cells.find((c) => c.id === activeCellId);
		if (cell) cell.type = cell.type === 'code' ? 'markdown' : 'code';
	}

	function deleteCell(id: number) {
		cells = cells.filter((c) => c.id !== id);
		if (activeCellId === id) activeCellId = null;
		saveNotebook();
	}

	function moveCell(index: number, direction: -1 | 1) {
		const target = index + direction;
		if (target < 0 || target >= cells.length) return;
		const updated = [...cells];
		[updated[index], updated[target]] = [updated[target], updated[index]];
		cells = updated;
		saveNotebook();
	}

	function setMode(newMode: 'edit' | 'view') {
		mode = newMode;
		if (newMode === 'view') activeCellId = null;
	}

	async function saveNotebook() {
		const body = {
			// Remove this line: path: notebookPath,
			kernel_type: kernel.toLowerCase(),
			next_cell_id: nextId,
			cells: cells.map((c) => ({
				cell_id: c.id,
				cell_type: c.type,
				source: c.content,
				outputs: c.outputs
			}))
		};

		const res = await fetch(`/api/notebook?path=${encodeURIComponent(notebookPath)}`, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(body)
		});

		if (!res.ok) {
			console.error('Failed to save notebook:', res.status);
		}
	}
</script>

<div class="flex h-screen overflow-hidden bg-background">
	{#if mode === 'edit'}
		<NotebookSidebar open={sidebarOpen} ontoggle={() => (sidebarOpen = !sidebarOpen)} />
	{/if}

	<div class="flex flex-1 flex-col overflow-hidden">
		<!-- Title bar -->
		<div class="border-b border-border">
			<div class="flex items-center gap-3 px-4 py-1.5">
				{#if mode === 'edit'}
					<input
						type="text"
						bind:value={notebookTitle}
						aria-label="Notebook title"
						class="min-w-0 flex-1 truncate rounded-md bg-transparent px-2 py-1 text-base font-medium text-foreground outline-none placeholder:text-muted-foreground hover:bg-white/3 focus:bg-white/3"
					/>
				{:else}
					<span class="min-w-0 flex-1 truncate px-2 py-1 text-base font-medium text-foreground"
						>{notebookTitle}</span
					>
				{/if}
			</div>
			{#if mode === 'edit'}
				<NotebookMenuBar />
			{/if}
		</div>

		<!-- Body -->
		<div class="flex flex-1 overflow-hidden">
			<div class="flex flex-1 flex-col overflow-hidden">
				<NotebookToolbar
					{mode}
					{activeCellType}
					{kernel}
					{runtimeStatus}
					{dataExplorerOpen}
					onaddcell={() => addCell()}
					onsetcelltype={setActiveCellType}
					onsetmode={setMode}
					ontoggleexplorer={() => (dataExplorerOpen = !dataExplorerOpen)}
				/>

				<!-- Cell area -->
				<div class="flex-1 overflow-y-auto bg-background">
					{#if loading}
						<div class="flex h-full items-center justify-center">
							<Loader2 class="size-6 animate-spin text-muted-foreground" />
						</div>
					{:else if loadError}
						<div class="flex h-full items-center justify-center text-sm text-muted-foreground">
							{loadError}
						</div>
					{:else}
						<div class="{mode === 'view' ? 'mx-auto max-w-4xl px-8' : 'px-4'} py-4">
							{#each cells as cell, index (cell.id)}
								<NotebookCell
									{cell}
									{index}
									isActive={activeCellId === cell.id}
									isLast={index === cells.length - 1}
									{mode}
									onrun={() => runCell(cell.id)}
									onactivate={() => (activeCellId = cell.id)}
									onchange={(val) => (cell.content = val)}
									ondelete={() => deleteCell(cell.id)}
									onmove={(dir) => moveCell(index, dir)}
									onaddcell={(type, at) => addCell(type, at)}
									onunrender={() => (cell.rendered = false)}
									onopenplot={() => {}}
								/>
							{/each}

							{#if mode === 'edit'}
								<div class="mr-10 ml-10 flex items-center justify-center gap-2 py-6">
									<button
										class="flex items-center gap-1.5 rounded-lg border border-dashed border-white/6 px-4 py-2 text-[0.8125rem] text-muted-foreground/50 transition-colors hover:border-white/12 hover:text-foreground"
										onclick={() => addCell('code')}
									>
										<Plus class="h-3.5 w-3.5" />
										Code
									</button>
									<button
										class="flex items-center gap-1.5 rounded-lg border border-dashed border-white/6 px-4 py-2 text-[0.8125rem] text-muted-foreground/50 transition-colors hover:border-white/12 hover:text-foreground"
										onclick={() => addCell('markdown')}
									>
										<Plus class="h-3.5 w-3.5" />
										Markdown
									</button>
								</div>
							{/if}
						</div>
					{/if}
				</div>
			</div>

			{#if mode === 'edit'}
				<div
					class="flex shrink-0 flex-col overflow-hidden border-l border-border {dataExplorerOpen
						? 'w-72'
						: 'w-0 border-l-0'} transition-[width] duration-200"
				>
					{#if dataExplorerOpen}
						<DataExplorer
							{tocEntries}
							plots={[]}
							onopenplot={() => {}}
							refreshKey={varsRefreshKey}
						/>
					{/if}
				</div>
			{/if}
		</div>
	</div>
</div>
