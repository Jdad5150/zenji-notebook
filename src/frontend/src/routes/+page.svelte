<script lang="ts">
	import DirectoryBrowser from '$lib/components/DirectoryBrowser.svelte';
	import { Separator } from '$lib/components/ui/separator';
	import { Button } from '$lib/components/ui/button';
	import { goto } from '$app/navigation';

	import { Folder, Clock, FolderOpen, FileText, Plus, ArrowLeft } from '@lucide/svelte';

	const STORAGE_KEY = 'zenji-recent-locations';
	let browsing = $state(false);
	let recents = $state<string[]>(loadRecents());

	// After the user picks a directory, we show the notebooks inside it here.
	let workspaceDir = $state<string | null>(null);
	let workspaceNotebooks = $state<{ name: string; path: string }[]>([]);

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

	function openNotebook(path: string) {
		saveRecent(path);
		goto('/notebook?path=' + encodeURIComponent(path));
	}

	async function openDirectory(dirPath: string) {
		saveRecent(dirPath);
		browsing = false;
		workspaceDir = dirPath;

		// Fetch notebooks (.znb files) in this directory.
		try {
			const res = await fetch(`/api/contents?path=${encodeURIComponent(dirPath)}`);
			if (res.ok) {
				const entries: { name: string; path: string; isDirectory: boolean }[] = await res.json();
				workspaceNotebooks = entries
					.filter((e) => !e.isDirectory && e.name.endsWith('.znb'))
					.map((e) => ({ name: e.name, path: e.path }));
			}
		} catch {
			workspaceNotebooks = [];
		}
	}

	async function createNotebook() {
		if (!workspaceDir) return;
		const name = `Untitled.znb`;
		const path = `${workspaceDir}/${name}`;

		// Create an empty notebook via PUT
		await fetch(`/api/notebook?path=${encodeURIComponent(path)}`, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ kernel_type: 'python', next_cell_id: 1, cells: [] })
		});

		openNotebook(path);
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
		<div class="w-full max-w-2xl space-y-8">

			{#if browsing}
				<!-- ── Directory browser ── -->
				<div class="text-center">
					<h1 class="text-3xl font-bold tracking-tight text-foreground">Open a folder</h1>
					<p class="mt-2 text-sm text-muted-foreground">Navigate to your project directory</p>
				</div>
				<DirectoryBrowser
					onSelect={(path) => { browsing = false; openNotebook(path); }}
					onOpenDir={(dirPath) => openDirectory(dirPath)}
					onCancel={() => (browsing = false)}
				/>

			{:else if workspaceDir}
				<!-- ── Workspace view: notebooks inside the chosen directory ── -->
				<div class="flex items-center gap-3">
					<button
						onclick={() => (workspaceDir = null)}
						class="text-muted-foreground/60 hover:text-foreground"
					>
						<ArrowLeft class="size-4" />
					</button>
					<div>
						<p class="text-xs text-muted-foreground">Workspace</p>
						<p class="truncate text-sm font-medium text-foreground">{workspaceDir}</p>
					</div>
				</div>

				{#if workspaceNotebooks.length === 0}
					<div class="rounded-xl border border-dashed border-white/10 p-10 text-center">
						<FileText class="mx-auto mb-3 size-8 text-muted-foreground/40" />
						<p class="text-sm text-muted-foreground">No notebooks here yet.</p>
						<Button class="mt-4" onclick={createNotebook}>
							<Plus class="mr-2 size-4" /> New notebook
						</Button>
					</div>
				{:else}
					<div class="overflow-hidden rounded-xl border border-white/6 bg-card">
						{#each workspaceNotebooks as nb, i (nb.path)}
							{#if i > 0}<Separator />{/if}
							<button
								class="flex w-full items-center gap-3 px-5 py-3.5 text-sm text-foreground/80 transition-colors hover:bg-white/4 hover:text-foreground"
								onclick={() => openNotebook(nb.path)}
							>
								<FileText class="size-4 shrink-0 text-[oklch(0.75_0.15_265)]" />
								<span class="truncate">{nb.name}</span>
							</button>
						{/each}
					</div>
					<Button variant="outline" class="w-full" onclick={createNotebook}>
						<Plus class="mr-2 size-4" /> New notebook
					</Button>
				{/if}

			{:else}
				<!-- ── Home screen ── -->
				<div class="text-center">
					<h1 class="animate-fade-up-blur text-5xl font-bold tracking-tight text-foreground">
						Notebook
					</h1>
					<p class="animate-fade-up-blur mt-3 text-base text-muted-foreground [animation-delay:200ms]">
						Choose a workspace to get started
					</p>
				</div>

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
									<p class="text-base font-medium text-foreground">Open a directory</p>
									<p class="text-sm text-muted-foreground">Navigate to your project folder</p>
								</div>
							</div>
						</div>
					</button>

					<!-- Recents -->
					{#if recents.length > 0}
						<div>
							<div class="mb-3 flex items-center gap-2 px-1 text-sm font-medium text-muted-foreground">
								<Clock class="size-4" />
								Recent
							</div>
							<div class="overflow-hidden rounded-xl border border-white/6 bg-card">
								{#each recents as path, i (path)}
									{#if i > 0}<Separator />{/if}
									<button
										class="flex w-full items-center gap-3 px-5 py-3.5 text-sm text-foreground/80 transition-colors hover:bg-white/4 hover:text-foreground"
										onclick={() => {
											if (path.endsWith('.znb')) openNotebook(path);
											else openDirectory(path);
										}}
									>
										{#if path.endsWith('.znb')}
											<FileText class="size-4 shrink-0 text-[oklch(0.75_0.15_265)]" />
										{:else}
											<Folder class="size-4 shrink-0 text-[oklch(0.75_0.15_265)]" />
										{/if}
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
