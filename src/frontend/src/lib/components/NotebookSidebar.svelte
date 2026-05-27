<script lang="ts">
	import { FileText, Folder, PanelLeftClose, PanelLeftOpen, Loader2 } from '@lucide/svelte';
	import { goto } from '$app/navigation';

	let {
		open = true,
		rootPath = '.',
		ontoggle
	}: {
		open?: boolean;
		rootPath?: string;
		ontoggle: () => void;
	} = $props();

	interface Entry {
		name: string;
		path: string;
		isDirectory: boolean;
		size?: number;
	}

	let entries = $state<Entry[]>([]);
	let loading = $state(false);
	let error = $state('');

	async function fetchEntries(path: string) {
		loading = true;
		error = '';
		try {
			const res = await fetch(`/api/contents?path=${encodeURIComponent(path)}`);
			if (!res.ok) throw new Error(`HTTP ${res.status}`);
			entries = await res.json();
		} catch (e: any) {
			error = e.message ?? 'Failed to load directory';
			entries = [];
		} finally {
			loading = false;
		}
	}

	$effect(() => {
		if (open) fetchEntries(rootPath);
	});
</script>

<div
	class="flex shrink-0 flex-col border-r border-border {open
		? 'w-64'
		: 'w-11'} transition-[width] duration-200"
>
	<!-- Header -->
	<div
		class="flex items-center {open
			? 'justify-between px-4'
			: 'justify-center'} border-b border-border py-3"
	>
		{#if open}
			<button class="cursor-pointer" onclick={() => goto('/')}>
				<span
					class="bg-linear-to-r from-[oklch(0.75_0.15_265)] via-foreground to-foreground bg-clip-text text-sm font-bold tracking-[0.2em] text-transparent uppercase"
					>Zenji</span
				>
			</button>
		{/if}
		<button
			class="rounded-md p-1 text-muted-foreground/50 transition-colors hover:bg-white/6 hover:text-foreground"
			aria-label={open ? 'Collapse sidebar' : 'Expand sidebar'}
			onclick={ontoggle}
		>
			{#if open}
				<PanelLeftClose class="size-4" />
			{:else}
				<PanelLeftOpen class="size-4" />
			{/if}
		</button>
	</div>

	{#if open}
		<div class="flex-1 overflow-y-auto px-3 py-4">
			<span
				class="px-2 text-[0.6875rem] font-semibold tracking-widest text-muted-foreground/60 uppercase"
				>Explorer</span
			>

			<div class="mt-3 space-y-0.5">
				{#if loading}
					<div class="flex items-center justify-center py-6">
						<Loader2 class="size-4 animate-spin text-muted-foreground/40" />
					</div>
				{:else if error}
					<p class="px-2 text-xs text-red-400">{error}</p>
				{:else if entries.length === 0}
					<p class="px-2 text-xs text-muted-foreground/50">Empty directory</p>
				{:else}
					{#each entries as entry (entry.name)}
						<button
							class="flex w-full items-center gap-2 rounded-md px-2.5 py-1.5 text-[0.8125rem] transition-colors hover:bg-white/4 {entry.isDirectory
								? 'text-foreground/70 hover:text-foreground'
								: entry.name.endsWith('.znb')
									? 'text-[oklch(0.75_0.15_265)] hover:text-[oklch(0.85_0.15_265)]'
									: 'text-muted-foreground/60 hover:text-muted-foreground'}"
							onclick={() => {
								if (entry.name.endsWith('.znb')) {
									goto(`/notebook?path=${encodeURIComponent(entry.path)}`);
								}
							}}
						>
							{#if entry.isDirectory}
								<Folder class="size-4 shrink-0 text-[oklch(0.75_0.15_265/0.7)]" />
							{:else}
								<FileText
									class="size-4 shrink-0 {entry.name.endsWith('.znb')
										? 'text-[oklch(0.75_0.15_265/0.8)]'
										: 'text-muted-foreground/40'}"
								/>
							{/if}
							<span class="truncate">{entry.name}</span>
						</button>
					{/each}
				{/if}
			</div>
		</div>
	{/if}
</div>
