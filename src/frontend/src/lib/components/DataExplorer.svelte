<script lang="ts">
	import { onMount } from 'svelte';
	import { Separator } from '$lib/components/ui/separator';
	import {
		Hash,
		ArrowLeft,
		Maximize2,
		ChevronDown,
		ChevronRight,
		Image,
		Box,
		Loader2
	} from '@lucide/svelte';

	let {
		tocEntries,
		plots = [],
		onopenplot,
		refreshKey = 0
	}: {
		tocEntries: { text: string; level: number; cellId: number }[];
		plots?: { cellId: number; src: string; title: string }[];
		onopenplot?: (index: number) => void;
		refreshKey?: number;
	} = $props();

	// ── Collapsible section state ──────────────────────────────────────
	let tocOpen = $state(true);
	let varsOpen = $state(true);
	let modsOpen = $state(true);
	let plotsOpen = $state(true);

	// ── Live variable data from kernel ─────────────────────────────────
	interface ApiVariable {
		name: string;
		type: string;
		value: string;
	}

	interface ApiModule {
		name: string;
		path: string;
	}

	let variables = $state<ApiVariable[]>([]);
	let modules = $state<ApiModule[]>([]);
	let varsLoading = $state(false);

	async function fetchVariables() {
		varsLoading = true;
		try {
			const res = await fetch('/api/variables');
			if (res.ok) {
				const data = await res.json();
				variables = data.variables ?? [];
				modules = data.modules ?? [];
			}
		} catch {
			// Silent fail — panel shows empty state
		} finally {
			varsLoading = false;
		}
	}

	onMount(() => {
		fetchVariables();
	});

	$effect(() => {
		if (refreshKey > 0) fetchVariables();
	});

	// ── Pill / badge colours per variable type ─────────────────────────
	function typeClass(typeName: string): string {
		const lower = typeName.toLowerCase();
		if (lower.includes('dataframe')) return 'text-[#89b4fa] bg-[oklch(0.55_0.25_265_/_0.1)]';
		if (lower.includes('ndarray') || lower.includes('array'))
			return 'text-[#a6e3a1] bg-[#a6e3a1]/10';
		if (lower.includes('tensor')) return 'text-[#cba6f7] bg-[#cba6f7]/10';
		if (lower === 'int' || lower === 'float' || lower.includes('int') || lower.includes('float'))
			return 'text-[#fab387] bg-[#fab387]/10';
		if (lower === 'bool') return 'text-[#94e2d5] bg-[#94e2d5]/10';
		if (lower === 'str') return 'text-[#f9e2af] bg-[#f9e2af]/10';
		if (lower === 'list' || lower === 'tuple' || lower === 'set')
			return 'text-[#89dceb] bg-[#89dceb]/10';
		if (lower === 'dict') return 'text-[#f2cdcd] bg-[#f2cdcd]/10';
		if (lower.includes('module')) return 'text-muted-foreground bg-white/[0.04]';
		return 'text-muted-foreground bg-white/[0.06]';
	}

	let selectedVar = $state<ApiVariable | null>(null);
</script>

<div class="flex h-full flex-col overflow-hidden">
	<!-- ═══ Table of Contents ═══ -->
	<div class="shrink-0">
		<button
			class="flex w-full items-center gap-2 px-3 py-2.5 text-left transition-colors hover:bg-white/3"
			onclick={() => (tocOpen = !tocOpen)}
		>
			{#if tocOpen}
				<ChevronDown class="size-3 text-muted-foreground" />
			{:else}
				<ChevronRight class="size-3 text-muted-foreground" />
			{/if}
			<span class="text-[0.6875rem] font-semibold tracking-widest text-muted-foreground uppercase"
				>Outline</span
			>
			{#if tocEntries.length > 0}
				<span class="ml-auto font-mono text-[0.6875rem] text-muted-foreground"
					>{tocEntries.length}</span
				>
			{/if}
		</button>
		{#if tocOpen}
			<div class="pb-1">
				{#if tocEntries.length === 0}
					<div
						class="mx-3 flex items-center gap-2 rounded-lg border border-white/4 bg-white/4 px-3 py-4"
					>
						<Hash class="size-4 text-muted-foreground" />
						<p class="text-xs text-muted-foreground">No headings found</p>
					</div>
				{:else}
					<div class="max-h-45 overflow-y-auto">
						{#each tocEntries as entry (entry.cellId)}
							<button
								class="flex w-full items-center gap-2 px-3 py-1.5 text-left transition-colors hover:bg-white/4"
							>
								<span class="w-4 text-right text-[0.625rem] text-muted-foreground/40"
									>H{entry.level}</span
								>
								<span
									class="truncate text-[0.6875rem] text-foreground/70"
									style="padding-left: {(entry.level - 1) * 12}px">{entry.text}</span
								>
							</button>
						{/each}
					</div>
				{/if}
			</div>
		{/if}
	</div>

	<Separator />

	<!-- ═══ Variables Section ═══ -->
	<div class="flex flex-1 flex-col overflow-hidden">
		<button
			class="flex w-full shrink-0 items-center gap-2 px-3 py-2.5 text-left transition-colors hover:bg-white/4"
			onclick={() => (varsOpen = !varsOpen)}
		>
			{#if varsOpen}
				<ChevronDown class="size-3 text-muted-foreground" />
			{:else}
				<ChevronRight class="size-3 text-muted-foreground" />
			{/if}
			<span class="text-[0.6875rem] font-semibold tracking-widest text-muted-foreground uppercase"
				>Variables</span
			>
			<span class="ml-auto font-mono text-[0.6875rem] text-muted-foreground"
				>{variables.length}</span
			>
		</button>
		{#if varsOpen}
			<div class="flex flex-1 flex-col overflow-hidden">
				{#if varsLoading}
					<div class="flex items-center justify-center py-8">
						<Loader2 class="size-4 animate-spin text-muted-foreground" />
					</div>
				{:else if variables.length === 0}
					<div
						class="mx-3 flex items-center gap-2 rounded-lg border border-white/4 bg-white/2 px-3 py-4"
					>
						<Box class="size-4 text-muted-foreground" />
						<p class="text-xs text-muted-foreground">No variables — run a cell first</p>
					</div>
				{:else if selectedVar}
					<!-- Variable detail view -->
					<div class="flex items-center gap-2 border-b border-white/6 px-3 py-2">
						<button
							class="rounded p-0.5 text-muted-foreground transition-colors hover:bg-white/6 hover:text-foreground"
							onclick={() => (selectedVar = null)}
							aria-label="Back to variable list"
						>
							<ArrowLeft class="size-3.5" />
						</button>
						<span class="font-mono text-xs text-foreground/90">{selectedVar.name}</span>
						<span
							class="inline-block rounded px-1.5 py-0.5 font-mono text-[0.5625rem] leading-none {typeClass(
								selectedVar.type
							)}">{selectedVar.type}</span
						>
					</div>
					<div class="max-h-75 overflow-y-auto">
						<div class="px-3 py-3">
							<span
								class="text-[0.625rem] font-medium tracking-wider text-muted-foreground uppercase"
								>Value</span
							>
							<pre
								class="mt-2 rounded border border-white/6 bg-white/2 p-3 font-mono text-[0.8125rem] break-all whitespace-pre-wrap text-foreground/90">{selectedVar.value}</pre>
						</div>
					</div>
				{:else}
					<!-- Variable table -->
					<div class="flex-1 overflow-x-hidden">
						<div class="flex items-center gap-0 border-b border-white/6 px-3 py-1">
							<span
								class="w-22.5 shrink-0 px-1.5 text-[0.625rem] font-medium tracking-wider text-muted-foreground uppercase"
								>Name</span
							>
							<span
								class="w-16 shrink-0 px-1.5 text-[0.625rem] font-medium tracking-wider text-muted-foreground uppercase"
								>Type</span
							>
							<span
								class="flex-1 px-1.5 text-[0.625rem] font-medium tracking-wider text-muted-foreground uppercase"
								>Value</span
							>
						</div>
						<div class="max-h-75 overflow-y-auto">
							{#each variables as v (v.name)}
								<button
									class="flex w-full items-center gap-0 px-3 py-1.25 text-left transition-colors hover:bg-white/4"
									onclick={() => (selectedVar = v)}
								>
									<span
										class="w-22.5 shrink-0 truncate px-1.5 font-mono text-[0.6875rem] text-foreground/90"
										>{v.name}</span
									>
									<span class="w-16 shrink-0 px-1.5">
										<span
											class="inline-block rounded px-1 py-0.5 font-mono text-[0.5625rem] leading-none {typeClass(
												v.type
											)}">{v.type}</span
										>
									</span>
									<span class="flex-1 truncate px-1.5 font-mono text-[0.625rem] text-foreground/60"
										>{v.value}</span
									>
								</button>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		{/if}
	</div>

	<Separator />

	<!-- ═══ Modules Section ═══ -->
	<div class="shrink-0">
		<button
			class="flex w-full items-center gap-2 px-3 py-2.5 text-left transition-colors hover:bg-white/3"
			onclick={() => (modsOpen = !modsOpen)}
		>
			{#if modsOpen}
				<ChevronDown class="size-3 text-muted-foreground" />
			{:else}
				<ChevronRight class="size-3 text-muted-foreground" />
			{/if}
			<span class="text-[0.6875rem] font-semibold tracking-widest text-muted-foreground uppercase"
				>Modules</span
			>
			<span class="ml-auto font-mono text-[0.6875rem] text-muted-foreground">{modules.length}</span>
		</button>
		{#if modsOpen}
			<div class="pb-1">
				{#if modules.length === 0}
					<div
						class="mx-3 flex items-center gap-2 rounded-lg border border-white/4 bg-white/2 px-3 py-4"
					>
						<Box class="size-4 text-muted-foreground" />
						<p class="text-xs text-muted-foreground">No modules imported</p>
					</div>
				{:else}
					<div class="max-h-30 overflow-y-auto">
						{#each modules as mod (mod.name)}
							<div class="flex items-center gap-2 px-3 py-1.5 text-[0.6875rem]">
								<span class="font-mono text-foreground/70">{mod.name}</span>
								<span
									class="ml-auto truncate font-mono text-[0.625rem] text-muted-foreground/50"
									title={mod.path}>{mod.path}</span
								>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		{/if}
	</div>

	<Separator />

	<!-- ═══ Plots Section ═══ -->
	<div class="shrink-0">
		<button
			class="flex w-full items-center gap-2 px-3 py-2.5 text-left transition-colors hover:bg-white/3"
			onclick={() => (plotsOpen = !plotsOpen)}
		>
			{#if plotsOpen}
				<ChevronDown class="size-3 text-muted-foreground" />
			{:else}
				<ChevronRight class="size-3 text-muted-foreground" />
			{/if}
			<span class="text-[0.6875rem] font-semibold tracking-widest text-muted-foreground uppercase"
				>Plots</span
			>
			{#if plots.length > 0}
				<span class="ml-auto font-mono text-[0.6875rem] text-muted-foreground">{plots.length}</span>
			{/if}
		</button>
		{#if plotsOpen}
			<div class="px-3 pb-3">
				{#if plots.length === 0}
					<div
						class="flex items-center gap-2 rounded-lg border border-white/4 bg-white/2 px-3 py-4"
					>
						<Image class="size-4 text-muted-foreground" />
						<p class="text-xs text-muted-foreground">No plots yet</p>
					</div>
				{:else}
					<div class="grid grid-cols-2 gap-1.5">
						{#each plots as plot, i (i)}
							<button
								class="group/thumb overflow-hidden rounded-md border border-white/6 transition-all hover:border-white/15 hover:shadow-md hover:shadow-black/20"
								onclick={() => onopenplot?.(i)}
							>
								<div class="relative">
									<img
										src={plot.src}
										alt={plot.title}
										class="block aspect-5/3 w-full bg-[#1a1b1e] object-cover"
									/>
									<div
										class="absolute inset-0 flex items-center justify-center bg-black/0 transition-colors group-hover/thumb:bg-black/30"
									>
										<Maximize2
											class="size-4 text-white opacity-0 transition-opacity group-hover/thumb:opacity-100"
										/>
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
