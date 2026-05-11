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
		goto('/notebook?path=' + encodeURIComponent(path));
	}
</script>

<div class="relative flex min-h-screen flex-col overflow-hidden bg-background p-8">
	<!-- Background glows -->
	<div class="pointer-events-none absolute inset-0">
		<div
			class="absolute top-1/4 left-1/2 h-175 w-900 -translate-x-1/2 -translate-y-1/2 rounded-full bg-[oklch(0.55_0.25_265)] opacity-[0.04] blur-[140px]"
		></div>
		<div
			class="absolute top-2/3 left-1/4 h-500 w-600 -translate-x-1/2 -translate-y-1/2 rounded-full bg-[oklch(0.55_0.20_300)] opacity-[0.035] blur-[120px]"
		></div>
		<div
			class="absolute top-1/2 right-1/4 h-400 w-500 -translate-x-1/2 -translate-y-1/2 rounded-full bg-[oklch(0.55_0.15_200)] opacity-[0.025] blur-[100px]"
		></div>
	</div>

	<!-- Brand mark -->
	<div class="relative animate-in duration-700 fade-in slide-in-from-left-2">
		<span
			class="bg-linear-to-r from-[oklch(0.75_0.15_265)] via-foreground to-foreground bg-clip-text text-xl font-bold tracking-[0.25em] text-transparent uppercase"
			>Zenji</span
		>
	</div>

	<div class="flex flex-1 items-center justify-center">
		<div class="w-full max-w-2xl space-y-12">
			<!-- Header -->
			<div class="text-center">
				<h1 class="animate-fade-up-blur text-5xl font-bold tracking-tight text-foreground">
					Notebook
				</h1>
				<p
					class="animate-fade-up-blur mt-3 text-base text-muted-foreground [animation-delay:200ms]"
				>
					Choose a workspace to get started
				</p>
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
					<button
						class="group/browse relative w-full cursor-pointer rounded-xl bg-linear-to-br from-white/8 via-white/3 to-transparent p-px text-left transition-all hover:from-[oklch(0.65_0.18_265/0.3)] hover:via-[oklch(0.55_0.15_300/0.15)] hover:to-transparent"
						onclick={() => (browsing = true)}
					>
						<div
							class="rounded-[11px] bg-card p-6 transition-colors group-hover/browse:bg-[oklch(0.22_0.005_260)]"
						>
							<div class="flex items-center gap-4">
								<div
									class="flex size-10 items-center justify-center rounded-lg bg-[oklch(0.55_0.25_265/0.1)] transition-colors group-hover/browse:bg-[oklch(0.55_0.25_265/0.15)]"
								>
									<FolderOpen class="size-5 text-[oklch(0.75_0.15_265)]" />
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
							<div
								class="mb-3 flex items-center gap-2 px-1 text-sm font-medium text-muted-foreground"
							>
								<Clock class="size-4" />
								Recent locations
							</div>
							<div class="overflow-hidden rounded-xl border border-white/6 bg-card">
								{#each recents as path, i (path)}
									{#if i > 0}
										<Separator />
									{/if}
									<button
										class="flex w-full items-center gap-3 px-5 py-3.5 text-sm text-foreground/80 transition-colors hover:bg-white/4 hover:text-foreground"
										onclick={() => openLocation(path)}
									>
										<Folder class="size-4 text-[oklch(0.75_0.15_265)]" />
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
