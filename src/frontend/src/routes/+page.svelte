<script lang="ts">
	import DirectoryBrowser from '$lib/components/DirectoryBrowser.svelte';
	import { Separator } from '$lib/components/ui/separator';
	import { goto } from '$app/navigation';

	import { Folder, Clock, FolderOpen } from '@lucide/svelte';

	const STORAGE_KEY = 'zenji-recent-locations';
	let browsing = $state(false);
	let recents = $state<string[]>(loadRecents());

	function loadRecents(): string[] {
		if (typeof window === 'undefined') return [];
		try {
			return JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '[]');
		} catch {
			return [];
		}
	}

	function saveRecent(path: string) {
		recents = [path, ...recents.filter((r) => r !== path)].slice(0, 5);
		localStorage.setItem(STORAGE_KEY, JSON.stringify(recents));
	}

	function openLocation(path: string) {
		saveRecent(path);
		goto('/notebook');
	}
</script>

<div class="relative flex min-h-screen flex-col overflow-hidden bg-background p-8">
	<!-- Background glows -->
	<div class="pointer-events-none absolute inset-0">
		<div class="absolute left-1/2 top-1/4 h-[700px] w-[900px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[oklch(0.55_0.25_265)] opacity-[0.04] blur-[140px]"></div>
		<div class="absolute left-1/4 top-2/3 h-[500px] w-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[oklch(0.55_0.20_300)] opacity-[0.035] blur-[120px]"></div>
		<div class="absolute right-1/4 top-1/2 h-[400px] w-[500px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[oklch(0.55_0.15_200)] opacity-[0.025] blur-[100px]"></div>
	</div>

	<!-- Brand mark -->
	<div class="relative animate-in fade-in slide-in-from-left-2 duration-700">
		<span class="bg-gradient-to-r from-[oklch(0.75_0.15_265)] via-foreground to-foreground bg-clip-text text-xl font-bold uppercase tracking-[0.25em] text-transparent">Zenji</span>
	</div>

	<div class="flex flex-1 items-center justify-center">
	<div class="w-full max-w-2xl space-y-12">
		<!-- Header -->
		<div class="text-center">
			<h1 class="animate-fade-up-blur text-5xl font-bold tracking-tight text-foreground">Notebook</h1>
			<p class="animate-fade-up-blur text-base text-muted-foreground [animation-delay:200ms] mt-3">Choose a workspace to get started</p>
		</div>

		{#if browsing}
			<DirectoryBrowser
				onSelect={(path) => {
					browsing = false;
					openLocation(path);
				}}
				onCancel={() => (browsing = false)}
			/>
		{:else}
			<div class="space-y-8">
				<!-- Browse button -->
				<button class="group/browse relative w-full cursor-pointer rounded-xl p-px text-left bg-gradient-to-br from-white/[0.08] via-white/[0.03] to-transparent transition-all hover:from-[oklch(0.65_0.18_265_/_0.3)] hover:via-[oklch(0.55_0.15_300_/_0.15)] hover:to-transparent" onclick={() => (browsing = true)}>
					<div class="rounded-[11px] bg-card p-6 transition-colors group-hover/browse:bg-[oklch(0.22_0.005_260)]">
						<div class="flex items-center gap-4">
							<div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[oklch(0.55_0.25_265_/_0.1)] transition-colors group-hover/browse:bg-[oklch(0.55_0.25_265_/_0.15)]">
								<FolderOpen class="h-5 w-5 text-[oklch(0.75_0.15_265)]" />
							</div>
							<div>
								<p class="text-base font-medium text-foreground">Browse directories</p>
								<p class="text-sm text-muted-foreground">Navigate to a folder to open</p>
							</div>
						</div>
					</div>
				</button>

				<!-- Recents -->
				{#if recents.length > 0}
					<div>
						<div class="mb-3 flex items-center gap-2 px-1 text-sm font-medium text-muted-foreground">
							<Clock class="h-4 w-4" />
							Recent locations
						</div>
						<div class="overflow-hidden rounded-xl border border-white/[0.06] bg-card">
							{#each recents as path, i}
								{#if i > 0}
									<Separator />
								{/if}
								<button
									class="flex w-full items-center gap-3 px-5 py-3.5 text-sm text-foreground/80 transition-colors hover:bg-white/[0.04] hover:text-foreground"
									onclick={() => openLocation(path)}
								>
									<Folder class="h-4 w-4 text-[oklch(0.75_0.15_265)]" />
									<span class="truncate">{path}</span>
								</button>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		{/if}
	</div>
	</div>
</div>
