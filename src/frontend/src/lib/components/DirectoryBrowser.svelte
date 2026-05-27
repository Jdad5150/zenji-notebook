<script lang="ts">
	import { onMount } from 'svelte';
	import type { DirectoryEntry } from '$lib/types';
	import { Button } from '$lib/components/ui/button';
	import { Separator } from '$lib/components/ui/separator';
	import * as Breadcrumb from '$lib/components/ui/breadcrumb';
	import { Folder, File, ChevronUp, LoaderCircle } from '@lucide/svelte';

	let {
		onSelect,
		onOpenDir,
		onCancel
	}: {
		/** Called when the user clicks a .znb file. */
		onSelect: (path: string) => void;
		/** Called when the user clicks "Open here" to use the current directory. */
		onOpenDir: (dirPath: string) => void;
		onCancel: () => void;
	} = $props();

	let currentPath = $state('');
	let entries = $state<DirectoryEntry[]>([]);
	let loading = $state(true);
	let error = $state('');

	// Breadcrumb segments derived from the current absolute path.
	// "/home/user/projects" → ["", "home", "user", "projects"]
	// We show "/" as the root label.
	const pathSegments = $derived(
		currentPath === '' ? [] : currentPath.split('/').filter((s, i) => i === 0 || s !== '')
	);

	async function navigate(path: string) {
		loading = true;
		error = '';
		currentPath = path;
		try {
			const res = await fetch(`/api/contents?path=${encodeURIComponent(path || '/')}`);
			if (!res.ok) throw new Error(`HTTP ${res.status}`);
			entries = await res.json();
		} catch (e: any) {
			error = e.message ?? 'Failed to load directory';
			entries = [];
		} finally {
			loading = false;
		}
	}

	function navigateToBreadcrumb(segmentIndex: number) {
		// Reconstruct the path up to segmentIndex.
		// segments: ["", "home", "user", "projects"] — join first N+1 with "/"
		const segs = currentPath.split('/');
		// segmentIndex 0 = root "/"
		if (segmentIndex === 0) return navigate('/');
		navigate(segs.slice(0, segmentIndex + 1).join('/'));
	}

	function goUp() {
		const idx = currentPath.lastIndexOf('/');
		if (idx <= 0) return navigate('/');
		navigate(currentPath.slice(0, idx));
	}

	function formatSize(bytes?: number): string {
		if (bytes == null) return '';
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
		return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
	}

	onMount(async () => {
		// Start at the user's home directory.
		try {
			const res = await fetch('/api/home');
			if (res.ok) {
				const data = await res.json();
				navigate(data.path);
			} else {
				navigate('/');
			}
		} catch {
			navigate('/');
		}
	});
</script>

<div class="flex h-112 flex-col rounded-lg border border-border bg-card">
	<!-- Breadcrumb -->
	<div class="px-4 py-2.5">
		<Breadcrumb.Root>
			<Breadcrumb.List>
				<!-- Root "/" -->
				<Breadcrumb.Item>
					{#if pathSegments.length === 0}
						<Breadcrumb.Page>/</Breadcrumb.Page>
					{:else}
						<Breadcrumb.Link onclick={() => navigate('/')} class="cursor-pointer">/</Breadcrumb.Link>
					{/if}
				</Breadcrumb.Item>

				{#each pathSegments.filter(Boolean) as segment, i (i)}
					<Breadcrumb.Separator />
					<Breadcrumb.Item>
						{#if i === pathSegments.filter(Boolean).length - 1}
							<Breadcrumb.Page>{segment}</Breadcrumb.Page>
						{:else}
							<Breadcrumb.Link
								onclick={() => {
									// Reconstruct path up to this segment
									const parts = currentPath.split('/').filter(Boolean);
									navigate('/' + parts.slice(0, i + 1).join('/'));
								}}
								class="cursor-pointer">{segment}</Breadcrumb.Link
							>
						{/if}
					</Breadcrumb.Item>
				{/each}
			</Breadcrumb.List>
		</Breadcrumb.Root>
	</div>

	<Separator />

	<!-- Entries -->
	<div class="flex-1 overflow-y-auto">
		{#if loading}
			<div class="flex h-full items-center justify-center">
				<LoaderCircle class="size-5 animate-spin text-muted-foreground" />
			</div>
		{:else if error}
			<div class="flex h-full items-center justify-center text-sm text-red-400">{error}</div>
		{:else if entries.length === 0}
			<div class="flex h-full items-center justify-center text-sm text-muted-foreground">
				Empty directory
			</div>
		{:else}
			{#if currentPath !== '/'}
				<Button
					variant="ghost"
					class="flex w-full justify-start gap-3 rounded-none px-4 py-2 text-sm text-muted-foreground"
					onclick={goUp}
				>
					<ChevronUp class="size-4" />
					<span>..</span>
				</Button>
			{/if}

			{#each entries as entry (entry.name)}
				<Button
					variant="ghost"
					class="flex w-full justify-start gap-3 rounded-none px-4 py-2 text-sm {entry.isDirectory
						? ''
						: entry.name.endsWith('.znb')
							? 'text-[oklch(0.75_0.15_265)]'
							: 'text-muted-foreground'}"
					onclick={() => {
						if (entry.isDirectory) {
							navigate(entry.path);
						} else if (entry.name.endsWith('.znb')) {
							onSelect(entry.path);
						}
					}}
				>
					{#if entry.isDirectory}
						<Folder class="size-4 shrink-0 text-blue-400" />
					{:else}
						<File
							class="size-4 shrink-0 {entry.name.endsWith('.znb')
								? 'text-[oklch(0.75_0.15_265)]'
								: 'text-muted-foreground'}"
						/>
					{/if}
					<span class="flex-1 text-left">{entry.name}</span>
					{#if !entry.isDirectory && entry.size != null}
						<span class="text-xs text-muted-foreground">{formatSize(entry.size)}</span>
					{/if}
				</Button>
			{/each}
		{/if}
	</div>

	<Separator />

	<!-- Actions -->
	<div class="flex items-center justify-between px-4 py-3">
		<span class="max-w-xs truncate text-xs text-muted-foreground">{currentPath || '/'}</span>
		<div class="flex gap-2">
			<Button variant="ghost" size="sm" onclick={onCancel}>Cancel</Button>
			<Button size="sm" onclick={() => onOpenDir(currentPath || '/')}>Open here</Button>
		</div>
	</div>
</div>
