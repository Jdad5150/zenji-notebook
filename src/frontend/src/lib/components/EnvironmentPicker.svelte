<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { LoaderCircle, Cpu, CheckCircle2 } from '@lucide/svelte';

	interface Env {
		kind: string;
		label: string;
		binary: string;
	}

	interface EnvData {
		saved: Env | null;
		detected: Env[];
	}

	let {
		dir = '.',
		onReady
	}: {
		/** Directory to scan for environments (the notebook's parent directory). */
		dir?: string;
		onReady: (env: Env) => void;
	} = $props();

	let loading = $state(true);
	let saving = $state(false);
	let error = $state('');
	let envData = $state<EnvData>({ saved: null, detected: [] });
	let selected = $state<Env | null>(null);

	async function loadEnvs() {
		loading = true;
		error = '';
		try {
			const res = await fetch(`/api/environment?dir=${encodeURIComponent(dir)}`);
			if (!res.ok) throw new Error(`HTTP ${res.status}`);
			envData = await res.json();
			// Pre-select: saved env if it exists, otherwise first detected
			if (envData.saved) {
				selected = envData.saved;
			} else if (envData.detected.length > 0) {
				selected = envData.detected[0];
			}
		} catch (e) {
			error = 'Failed to load environments. Is the server running?';
		} finally {
			loading = false;
		}
	}

	async function confirmSelection() {
		if (!selected) return;
		saving = true;
		error = '';
		try {
			const res = await fetch('/api/environment', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ ...selected, dir })
			});
			if (!res.ok) {
				const body = await res.json().catch(() => ({}));
				throw new Error(body.error ?? `HTTP ${res.status}`);
			}
			onReady(selected);
		} catch (e: any) {
			error = e.message ?? 'Failed to start kernel.';
		} finally {
			saving = false;
		}
	}

	$effect(() => {
		loadEnvs();
	});
</script>

<div class="flex flex-col gap-6">
	<div class="text-center">
		<p class="text-sm text-muted-foreground">
			Select the environment for this notebook.
			<br />
			We'll remember your choice in <code class="text-xs">.zenji.json</code>.
		</p>
	</div>

	{#if loading}
		<div class="flex items-center justify-center py-8">
			<LoaderCircle class="size-5 animate-spin text-muted-foreground" />
		</div>
	{:else if envData.detected.length === 0 && !envData.saved}
		<div
			class="rounded-lg border border-border bg-card p-6 text-center text-sm text-muted-foreground"
		>
			<Cpu class="mx-auto mb-3 size-8 opacity-40" />
			<p class="font-medium text-foreground">No environments detected</p>
			<p class="mt-1 text-xs">
				Create a virtual environment in the notebook's directory, then refresh.
			</p>
			<pre
				class="mt-3 rounded bg-white/5 px-3 py-2 text-left text-xs text-muted-foreground">uv venv        # Python via uv
python -m venv .venv  # plain venv</pre>
			<p class="mt-2 text-xs text-muted-foreground/60">Scanning: <code>{dir}</code></p>
			<Button variant="outline" size="sm" class="mt-4" onclick={loadEnvs}>Refresh</Button>
		</div>
	{:else}
		<div class="overflow-hidden rounded-xl border border-white/6 bg-card">
			{#each envData.detected as env (env.binary)}
				<button
					class="flex w-full items-center gap-3 px-5 py-4 text-left text-sm transition-colors hover:bg-white/4
                        {selected?.binary === env.binary ? 'bg-[oklch(0.55_0.25_265/0.08)]' : ''}"
					onclick={() => (selected = env)}
				>
					<div
						class="flex size-8 shrink-0 items-center justify-center rounded-lg
                           {selected?.binary === env.binary
							? 'bg-[oklch(0.55_0.25_265/0.15)]'
							: 'bg-white/5'}"
					>
						{#if selected?.binary === env.binary}
							<CheckCircle2 class="size-4 text-[oklch(0.75_0.15_265)]" />
						{:else}
							<Cpu class="size-4 text-muted-foreground" />
						{/if}
					</div>
					<div class="min-w-0 flex-1">
						<p class="font-medium text-foreground">{env.label}</p>
						<p class="truncate text-xs text-muted-foreground">{env.binary}</p>
					</div>
				</button>
			{/each}
		</div>

		{#if error}
			<p class="text-center text-sm text-red-400">{error}</p>
		{/if}

		<Button class="w-full" disabled={!selected || saving} onclick={confirmSelection}>
			{#if saving}
				<LoaderCircle class="mr-2 size-4 animate-spin" />
				Starting kernel…
			{:else}
				Use {selected?.label ?? 'selected environment'}
			{/if}
		</Button>
	{/if}
</div>
