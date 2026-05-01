<script lang="ts">
	import { Separator } from '$lib/components/ui/separator';
	import { Hash, ArrowLeft, Copy, Maximize2, ChevronDown, ChevronRight, Image } from '@lucide/svelte';

	let {
		tocEntries,
		plots = [],
		onopenplot
	}: {
		tocEntries: { text: string; level: number; cellId: number }[];
		plots?: { cellId: number; src: string; title: string }[];
		onopenplot?: (index: number) => void;
	} = $props();

	// ── Collapsible section state ──────────────────────────────────────
	let tocOpen = $state(true);
	let varsOpen = $state(true);
	let plotsOpen = $state(true);

	// ── Mock variable data (Spyder-style) ──────────────────────────────
	type VarType = 'DataFrame' | 'ndarray' | 'Tensor' | 'int' | 'float' | 'str' | 'list' | 'dict' | 'bool';

	interface Variable {
		name: string;
		type: VarType;
		size: string;
		value: string;
		detail: DataFrameDetail | ArrayDetail | ScalarDetail | DictDetail;
	}

	interface DataFrameDetail {
		kind: 'dataframe';
		shape: [number, number];
		columns: { name: string; dtype: string; nulls: number }[];
		rows: Record<string, string>[];
	}

	interface ArrayDetail {
		kind: 'array';
		shape: string;
		dtype: string;
		min: string;
		max: string;
		mean: string;
		std: string;
		values: string;
	}

	interface ScalarDetail {
		kind: 'scalar';
		repr: string;
	}

	interface DictDetail {
		kind: 'dict';
		entries: { key: string; type: string; value: string }[];
	}

	const mockVariables: Variable[] = [
		{
			name: 'df',
			type: 'DataFrame',
			size: '1000 × 6',
			value: 'DataFrame (1000 rows)',
			detail: {
				kind: 'dataframe',
				shape: [1000, 6],
				columns: [
					{ name: 'id', dtype: 'int64', nulls: 0 },
					{ name: 'name', dtype: 'object', nulls: 3 },
					{ name: 'score', dtype: 'float64', nulls: 12 },
					{ name: 'grade', dtype: 'object', nulls: 0 },
					{ name: 'active', dtype: 'bool', nulls: 0 },
					{ name: 'date', dtype: 'datetime64', nulls: 5 }
				],
				rows: [
					{ id: '0', name: 'Alice', score: '92.5', grade: 'A', active: 'True', date: '2024-01-15' },
					{ id: '1', name: 'Bob', score: '87.3', grade: 'B+', active: 'True', date: '2024-01-16' },
					{ id: '2', name: 'Carol', score: '95.1', grade: 'A', active: 'False', date: '2024-01-17' },
					{ id: '3', name: 'Dan', score: '78.9', grade: 'C+', active: 'True', date: '2024-01-18' },
					{ id: '4', name: 'Eve', score: '91.0', grade: 'A-', active: 'True', date: '2024-01-19' }
				]
			}
		},
		{
			name: 'data',
			type: 'ndarray',
			size: '(100,)',
			value: '[0.23, 1.45, -0.67, ...]',
			detail: { kind: 'array', shape: '(100,)', dtype: 'float64', min: '-2.341', max: '3.127', mean: '0.042', std: '0.987', values: '[0.234, 1.451, -0.672, 0.891, -1.234, 2.105, -0.445, 0.667, 1.892, -0.123, ...]' }
		},
		{
			name: 'model',
			type: 'Tensor',
			size: '(32, 128)',
			value: 'Tensor (32×128)',
			detail: { kind: 'array', shape: '(32, 128)', dtype: 'float32', min: '-0.892', max: '0.934', mean: '0.001', std: '0.412', values: '[[0.012, -0.234, ...], [0.891, 0.445, ...], ...]' }
		},
		{ name: 'MAX_RETRIES', type: 'int', size: '28 B', value: '3', detail: { kind: 'scalar', repr: '3' } },
		{ name: 'PI', type: 'float', size: '24 B', value: '3.14159', detail: { kind: 'scalar', repr: '3.14159' } },
		{ name: 'is_active', type: 'bool', size: '28 B', value: 'True', detail: { kind: 'scalar', repr: 'True' } },
		{ name: 'single', type: 'str', size: '54 B', value: "'hello'", detail: { kind: 'scalar', repr: "'hello'" } },
		{ name: 'items', type: 'list', size: '10', value: '[0, 1, 2, 3, 4, 5, ...]', detail: { kind: 'scalar', repr: '[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]' } },
		{
			name: 'config',
			type: 'dict',
			size: '3 keys',
			value: "{'lr': 0.001, ...}",
			detail: { kind: 'dict', entries: [{ key: 'lr', type: 'float', value: '0.001' }, { key: 'epochs', type: 'int', value: '100' }, { key: 'batch_size', type: 'int', value: '32' }] }
		}
	];

	let selectedVar = $state<Variable | null>(null);

	const typeColor: Record<string, string> = {
		DataFrame: 'text-blue-400 bg-blue-400/10',
		ndarray: 'text-orange-400 bg-orange-400/10',
		Tensor: 'text-green-400 bg-green-400/10',
		int: 'text-[oklch(0.75_0.15_60)] bg-[oklch(0.75_0.15_60_/_0.1)]',
		float: 'text-[oklch(0.75_0.15_60)] bg-[oklch(0.75_0.15_60_/_0.1)]',
		str: 'text-[oklch(0.75_0.15_140)] bg-[oklch(0.75_0.15_140_/_0.1)]',
		list: 'text-purple-400 bg-purple-400/10',
		dict: 'text-pink-400 bg-pink-400/10',
		bool: 'text-[oklch(0.75_0.15_60)] bg-[oklch(0.75_0.15_60_/_0.1)]'
	};
</script>

<div class="flex h-full flex-col overflow-y-auto overflow-x-hidden">

	<!-- ═══ TOC Section ═══ -->
	<div class="shrink-0">
		<button
			class="flex w-full items-center gap-2 px-3 py-2.5 text-left transition-colors hover:bg-white/[0.03]"
			onclick={() => tocOpen = !tocOpen}
		>
			{#if tocOpen}<ChevronDown class="size-3 text-muted-foreground" />{:else}<ChevronRight class="size-3 text-muted-foreground" />{/if}
			<span class="text-[11px] font-semibold uppercase tracking-widest text-muted-foreground">Table of Contents</span>
		</button>
		{#if tocOpen}
			<nav class="px-3 pb-3 space-y-0.5">
				{#each tocEntries as entry}
					<button
						class="flex w-full items-center gap-2 rounded-md px-2.5 py-1 text-left text-[12px] text-foreground/80 transition-colors hover:bg-white/[0.04] hover:text-foreground"
						style="padding-left: {(entry.level - 1) * 12 + 10}px"
					>
						<Hash class="size-3 shrink-0 text-muted-foreground" />
						<span class="truncate">{entry.text}</span>
					</button>
				{/each}
				{#if tocEntries.length === 0}
					<p class="px-2.5 text-[12px] text-muted-foreground">Add markdown headings to build a table of contents</p>
				{/if}
			</nav>
		{/if}
	</div>

	<Separator />

	<!-- ═══ Variables Section ═══ -->
	<div class="shrink-0">
		<button
			class="flex w-full items-center gap-2 px-3 py-2.5 text-left transition-colors hover:bg-white/[0.03]"
			onclick={() => { varsOpen = !varsOpen; if (!varsOpen) selectedVar = null; }}
		>
			{#if varsOpen}<ChevronDown class="size-3 text-muted-foreground" />{:else}<ChevronRight class="size-3 text-muted-foreground" />{/if}
			<span class="text-[11px] font-semibold uppercase tracking-widest text-muted-foreground">Variables</span>
			<span class="ml-auto text-[11px] text-muted-foreground font-mono">{mockVariables.length}</span>
		</button>
		{#if varsOpen}
			<div class="pb-1">
				{#if selectedVar}
					<!-- Detail view -->
					<div class="flex items-center gap-2 px-3 py-1.5 border-b border-white/[0.06]">
						<button
							class="rounded p-0.5 text-muted-foreground hover:bg-white/[0.06] hover:text-foreground transition-colors"
							title="Back" aria-label="Back"
							onclick={() => selectedVar = null}
						>
							<ArrowLeft class="size-3.5" />
						</button>
						<span class="font-mono text-[12px] text-foreground">{selectedVar.name}</span>
						<span class="rounded px-1 py-0.5 font-mono text-[9px] leading-none {typeColor[selectedVar.type] ?? 'text-muted-foreground bg-white/[0.06]'}">{selectedVar.type}</span>
						<div class="flex-1"></div>
						<button class="rounded p-0.5 text-muted-foreground/60 hover:bg-white/[0.06] hover:text-foreground transition-colors" title="Copy" aria-label="Copy value">
							<Copy class="size-3" />
						</button>
						<button class="rounded p-0.5 text-muted-foreground/60 hover:bg-white/[0.06] hover:text-foreground transition-colors" title="Expand" aria-label="Open in full view">
							<Maximize2 class="size-3" />
						</button>
					</div>

					<div class="max-h-[300px] overflow-y-auto">
						{#if selectedVar.detail.kind === 'dataframe'}
							{@const detail = selectedVar.detail}
							<div class="px-3 py-2">
								<span class="text-[10px] font-medium uppercase tracking-wider text-muted-foreground">Schema · {detail.shape[0]} × {detail.shape[1]}</span>
								<div class="mt-1.5">
									{#each detail.columns as col}
										<div class="flex items-center gap-2 py-[3px] px-1">
											<span class="w-[70px] shrink-0 truncate font-mono text-[11px] text-foreground/80">{col.name}</span>
											<span class="font-mono text-[10px] text-muted-foreground">{col.dtype}</span>
											{#if col.nulls > 0}<span class="font-mono text-[10px] text-orange-400">{col.nulls} null</span>{/if}
										</div>
									{/each}
								</div>
							</div>
							<Separator />
							<div class="px-3 py-2">
								<span class="text-[10px] font-medium uppercase tracking-wider text-muted-foreground">Preview</span>
								<div class="mt-1.5 overflow-x-auto rounded border border-white/[0.06]">
									<table class="w-full text-[10px]">
										<thead><tr class="border-b border-white/[0.08]">
											{#each detail.columns as col}<th class="whitespace-nowrap px-2 py-1 text-left font-mono font-medium text-muted-foreground">{col.name}</th>{/each}
										</tr></thead>
										<tbody>
											{#each detail.rows as row, i}
												<tr class="border-b border-white/[0.04] {i % 2 === 1 ? 'bg-white/[0.02]' : ''}">
													{#each detail.columns as col}<td class="whitespace-nowrap px-2 py-1 font-mono text-foreground/70">{row[col.name]}</td>{/each}
												</tr>
											{/each}
										</tbody>
									</table>
								</div>
								<p class="mt-1.5 text-[10px] text-muted-foreground">Showing 5 of {detail.shape[0]} rows</p>
							</div>
						{:else if selectedVar.detail.kind === 'array'}
							{@const detail = selectedVar.detail}
							<div class="px-3 py-2">
								<span class="text-[10px] font-medium uppercase tracking-wider text-muted-foreground">Statistics</span>
								<div class="mt-1.5 grid grid-cols-2 gap-x-4 gap-y-1 px-1">
									{#each [['shape', detail.shape], ['dtype', detail.dtype], ['min', detail.min], ['max', detail.max], ['mean', detail.mean], ['std', detail.std]] as [label, val]}
										<div class="flex items-center justify-between py-[2px]">
											<span class="text-[11px] text-muted-foreground">{label}</span>
											<span class="font-mono text-[11px] text-foreground/80">{val}</span>
										</div>
									{/each}
								</div>
							</div>
							<Separator />
							<div class="px-3 py-2">
								<span class="text-[10px] font-medium uppercase tracking-wider text-muted-foreground">Values</span>
								<pre class="mt-1.5 rounded border border-white/[0.06] bg-white/[0.02] p-2 font-mono text-[10px] leading-relaxed text-foreground/70 overflow-x-auto">{detail.values}</pre>
							</div>
						{:else if selectedVar.detail.kind === 'dict'}
							{@const detail = selectedVar.detail}
							<div class="px-3 py-2">
								<span class="text-[10px] font-medium uppercase tracking-wider text-muted-foreground">Entries · {detail.entries.length} keys</span>
								<div class="mt-1.5">
									{#each detail.entries as entry}
										<div class="flex items-center gap-2 py-[3px] px-1">
											<span class="font-mono text-[11px] text-[oklch(0.75_0.15_200)]">"{entry.key}"</span>
											<span class="font-mono text-[10px] text-muted-foreground">→</span>
											<span class="font-mono text-[11px] text-foreground/80">{entry.value}</span>
											<span class="font-mono text-[9px] text-muted-foreground">{entry.type}</span>
										</div>
									{/each}
								</div>
							</div>
						{:else if selectedVar.detail.kind === 'scalar'}
							<div class="px-3 py-3">
								<span class="text-[10px] font-medium uppercase tracking-wider text-muted-foreground">Value</span>
								<pre class="mt-2 rounded border border-white/[0.06] bg-white/[0.02] p-3 font-mono text-[13px] text-foreground/90">{selectedVar.detail.repr}</pre>
							</div>
						{/if}
					</div>
				{:else}
					<!-- Variable table -->
					<div class="overflow-x-hidden">
						<div class="flex items-center gap-0 border-b border-white/[0.06] px-3 py-1">
							<span class="w-[90px] shrink-0 text-[10px] font-medium uppercase tracking-wider text-muted-foreground px-1.5">Name</span>
							<span class="w-[62px] shrink-0 text-[10px] font-medium uppercase tracking-wider text-muted-foreground px-1.5">Type</span>
							<span class="w-[52px] shrink-0 text-[10px] font-medium uppercase tracking-wider text-muted-foreground px-1.5">Size</span>
							<span class="flex-1 text-[10px] font-medium uppercase tracking-wider text-muted-foreground px-1.5">Value</span>
						</div>
						<div class="max-h-[200px] overflow-y-auto">
							{#each mockVariables as v}
								<button
									class="flex w-full items-center gap-0 px-3 py-[5px] text-left transition-colors hover:bg-white/[0.04]"
									onclick={() => selectedVar = v}
								>
									<span class="w-[90px] shrink-0 truncate px-1.5 font-mono text-[11px] text-foreground/90">{v.name}</span>
									<span class="w-[62px] shrink-0 px-1.5">
										<span class="inline-block rounded px-1 py-0.5 font-mono text-[9px] leading-none {typeColor[v.type] ?? 'text-muted-foreground bg-white/[0.06]'}">{v.type}</span>
									</span>
									<span class="w-[52px] shrink-0 truncate px-1.5 font-mono text-[10px] text-muted-foreground">{v.size}</span>
									<span class="flex-1 truncate px-1.5 font-mono text-[10px] text-foreground/60">{v.value}</span>
								</button>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		{/if}
	</div>

	<Separator />

	<!-- ═══ Plots Section ═══ -->
	<div class="shrink-0">
		<button
			class="flex w-full items-center gap-2 px-3 py-2.5 text-left transition-colors hover:bg-white/[0.03]"
			onclick={() => plotsOpen = !plotsOpen}
		>
			{#if plotsOpen}<ChevronDown class="size-3 text-muted-foreground" />{:else}<ChevronRight class="size-3 text-muted-foreground" />{/if}
			<span class="text-[11px] font-semibold uppercase tracking-widest text-muted-foreground">Plots</span>
			{#if plots.length > 0}
				<span class="ml-auto text-[11px] text-muted-foreground font-mono">{plots.length}</span>
			{/if}
		</button>
		{#if plotsOpen}
			<div class="px-3 pb-3">
				{#if plots.length === 0}
					<div class="flex items-center gap-2 rounded-lg border border-white/[0.04] bg-white/[0.02] px-3 py-4">
						<Image class="size-4 text-muted-foreground" />
						<p class="text-[12px] text-muted-foreground">No plots yet</p>
					</div>
				{:else}
					<div class="grid grid-cols-2 gap-1.5">
						{#each plots as plot, i}
							<button
								class="group/thumb overflow-hidden rounded-md border border-white/[0.06] transition-all hover:border-white/[0.15] hover:shadow-md hover:shadow-black/20"
								onclick={() => onopenplot?.(i)}
							>
								<div class="relative">
									<img src={plot.src} alt={plot.title} class="block w-full aspect-[5/3] object-cover bg-[#1a1b1e]" />
									<div class="absolute inset-0 flex items-center justify-center bg-black/0 transition-colors group-hover/thumb:bg-black/30">
										<Maximize2 class="size-4 text-white opacity-0 transition-opacity group-hover/thumb:opacity-100" />
									</div>
								</div>
							</button>
						{/each}
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>
