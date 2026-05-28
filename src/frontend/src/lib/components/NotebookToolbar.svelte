<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import { Separator } from '$lib/components/ui/separator';
	import {
		Play,
		Plus,
		ChevronDown,
		PanelRightClose,
		PanelRightOpen,
		Eye,
		Pencil
	} from '@lucide/svelte';

	let {
		mode,
		activeCellType,
		kernel,
		runtimeStatus,
		dataExplorerOpen,
		onaddcell,
		onsetcelltype,
		onsetmode,
		ontoggleexplorer,
		onkernelclick
	}: {
		mode: 'edit' | 'view';
		activeCellType: 'code' | 'markdown';
		kernel: string;
		runtimeStatus: 'idle' | 'running' | 'error';
		dataExplorerOpen: boolean;
		onaddcell: () => void;
		onsetcelltype: () => void;
		onsetmode: (mode: 'edit' | 'view') => void;
		ontoggleexplorer: () => void;
		onkernelclick: () => void;
	} = $props();

	const kernelLabel = $derived(kernel ? kernel[0].toUpperCase() + kernel.slice(1) : '—');

	const statusColor = $derived(
		runtimeStatus === 'running'
			? 'text-green-400'
			: runtimeStatus === 'error'
				? 'text-red-400'
				: 'text-muted-foreground/60'
	);

	const statusDotColor = $derived(
		runtimeStatus === 'running'
			? 'bg-green-400'
			: runtimeStatus === 'error'
				? 'bg-red-400'
				: 'bg-muted-foreground/40'
	);

	const statusLabel = $derived(
		runtimeStatus === 'running' ? 'Running' : runtimeStatus === 'error' ? 'Error' : 'Idle'
	);
</script>

<div class="flex items-center justify-between border-b border-border px-4 py-1">
	{#if mode === 'edit'}
		<div class="flex items-center gap-1">
			<Button
				variant="ghost"
				size="icon"
				class="hover:!bg-foreground/10! size-7 rounded-md p-0"
				title="Add Cell"
				onclick={onaddcell}
			>
				<Plus class="size-4" />
			</Button>
			<Separator orientation="vertical" class="mx-1 h-4" />
			<button
				class="flex h-7 items-center gap-1.5 rounded-md px-2.5 text-[0.8125rem] text-muted-foreground transition-colors hover:bg-white/6 hover:text-foreground"
				title="Run All Cells"
			>
				<Play class="size-3.5" />
				Run All
			</button>
			<Separator orientation="vertical" class="mx-1 h-4" />
			<button
				class="flex h-7 items-center gap-1 rounded-md px-2.5 text-[0.8125rem] text-muted-foreground transition-colors hover:bg-white/6 hover:text-foreground"
				onclick={onsetcelltype}
			>
				{activeCellType === 'code' ? 'Code' : 'Markdown'}
				<ChevronDown class="size-3 opacity-50" />
			</button>
		</div>
	{:else}
		<div></div>
	{/if}

	<div class="flex items-center gap-2">
		<!-- Mode toggle -->
		<div class="flex items-center rounded-lg bg-white/4 p-0.5">
			<button
				class="flex items-center gap-1.5 rounded-md px-3 py-1 text-[0.8125rem] transition-all {mode ===
				'edit'
					? 'bg-white/8 text-foreground shadow-sm'
					: 'text-muted-foreground hover:text-foreground'}"
				onclick={() => onsetmode('edit')}
			>
				<Pencil class="size-3" />
				Edit
			</button>
			<button
				class="flex items-center gap-1.5 rounded-md px-3 py-1 text-[0.8125rem] transition-all {mode ===
				'view'
					? 'bg-white/8 text-foreground shadow-sm'
					: 'text-muted-foreground hover:text-foreground'}"
				onclick={() => onsetmode('view')}
			>
				<Eye class="size-3" />
				View
			</button>
		</div>
		{#if mode === 'edit'}
			<Separator orientation="vertical" class="h-4" />
			<div class="flex items-center gap-1.5">
				<span class="relative flex size-2">
					{#if runtimeStatus === 'running'}
						<span
							class="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-400 opacity-75"
						></span>
					{/if}
					<span class="relative inline-flex size-2 rounded-full {statusDotColor}"></span>
				</span>
				<span class="text-xs {statusColor}">{statusLabel}</span>
			</div>
			<Separator orientation="vertical" class="h-4" />
			<button
				class="flex h-7 items-center gap-1 rounded-md px-2 text-xs text-muted-foreground transition-colors hover:bg-white/6 hover:text-foreground"
				onclick={onkernelclick}
			>
				{kernelLabel}
				<ChevronDown class="size-3 opacity-50" />
			</button>
			<Separator orientation="vertical" class="h-4" />
			<button
				class="rounded-md p-1.5 text-muted-foreground/60 transition-colors hover:bg-white/6 hover:text-foreground"
				aria-label={dataExplorerOpen ? 'Collapse data explorer' : 'Expand data explorer'}
				onclick={ontoggleexplorer}
			>
				{#if dataExplorerOpen}
					<PanelRightClose class="size-4" />
				{:else}
					<PanelRightOpen class="size-4" />
				{/if}
			</button>
		{/if}
	</div>
</div>
