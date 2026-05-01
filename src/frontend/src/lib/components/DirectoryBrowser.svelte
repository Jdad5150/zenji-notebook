<script lang="ts">
	import { onMount } from 'svelte';
	import { fetchDirectory } from '$lib/mock-data';
	import type { DirectoryEntry } from '$lib/types';
	import { Button } from '$lib/components/ui/button';
	import { Separator } from '$lib/components/ui/separator';
	import * as Breadcrumb from '$lib/components/ui/breadcrumb';
	import { Folder, File, ChevronUp, Loader2 } from '@lucide/svelte';

	let {
		onSelect,
		onCancel
	}: {
		onSelect: (path: string) => void;
		onCancel: () => void;
	} = $props();

	let currentPath = $state('/');
	let entries = $state<DirectoryEntry[]>([]);
	let loading = $state(false);

	const pathSegments = $derived(
		currentPath === '/'
			? ['/']
			: ['/', ...currentPath.split('/').filter(Boolean)]
	);

	async function navigate(path: string) {
		loading = true;
		currentPath = path;
		entries = await fetchDirectory(path);
		loading = false;
	}

	function navigateToBreadcrumb(index: number) {
		if (index === 0) return navigate('/');
		const path = '/' + pathSegments.slice(1, index + 1).join('/');
		navigate(path);
	}

	function formatSize(bytes?: number): string {
		if (bytes == null) return '';
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
		return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
	}

	onMount(() => {
		navigate('/');
	});
</script>

<div class="flex h-[28rem] flex-col rounded-lg border border-border bg-card">
	<!-- Breadcrumb -->
	<div class="px-4 py-2.5">
		<Breadcrumb.Root>
			<Breadcrumb.List>
				{#each pathSegments as segment, i}
					{#if i > 0}
						<Breadcrumb.Separator />
					{/if}
					<Breadcrumb.Item>
						{#if i === pathSegments.length - 1}
							<Breadcrumb.Page>{segment === '/' ? '~' : segment}</Breadcrumb.Page>
						{:else}
							<Breadcrumb.Link onclick={() => navigateToBreadcrumb(i)} class="cursor-pointer">
								{segment === '/' ? '~' : segment}
							</Breadcrumb.Link>
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
				<Loader2 class="h-5 w-5 animate-spin text-muted-foreground" />
			</div>
		{:else if entries.length === 0}
			<div class="flex h-full items-center justify-center text-sm text-muted-foreground">
				Empty directory
			</div>
		{:else}
			{#if currentPath !== '/'}
				<Button
					variant="ghost"
					class="flex w-full justify-start gap-3 rounded-none px-4 py-2 text-sm text-muted-foreground"
					onclick={() => {
						const parent = currentPath.substring(0, currentPath.lastIndexOf('/')) || '/';
						navigate(parent);
					}}
				>
					<ChevronUp class="h-4 w-4" />
					<span>..</span>
				</Button>
			{/if}

			{#each entries as entry}
				<Button
					variant="ghost"
					class="flex w-full justify-start gap-3 rounded-none px-4 py-2 text-sm {!entry.isDirectory ? 'cursor-default' : ''}"
					onclick={() => {
						if (entry.isDirectory) navigate(entry.path);
					}}
				>
					{#if entry.isDirectory}
						<Folder class="h-4 w-4 text-blue-400" />
					{:else}
						<File class="h-4 w-4 text-muted-foreground" />
					{/if}
					<span class="flex-1 text-left">{entry.name}</span>
					{#if !entry.isDirectory && entry.size}
						<span class="text-xs text-muted-foreground">{formatSize(entry.size)}</span>
					{/if}
				</Button>
			{/each}
		{/if}
	</div>

	<Separator />

	<!-- Actions -->
	<div class="flex items-center justify-between px-4 py-3">
		<span class="truncate text-xs text-muted-foreground">{currentPath}</span>
		<div class="flex gap-2">
			<Button variant="ghost" size="sm" onclick={onCancel}>Cancel</Button>
			<Button size="sm" onclick={() => onSelect(currentPath)}>Open here</Button>
		</div>
	</div>
</div>
