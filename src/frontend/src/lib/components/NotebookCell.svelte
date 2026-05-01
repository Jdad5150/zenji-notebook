<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import CodeCell from './CodeCell.svelte';
	import RenderedCode from './RenderedCode.svelte';
	import {
		Play,
		Plus,
		Trash2,
		ChevronUp,
		ChevronDownIcon,
		GripVertical,
		Ellipsis,
		Maximize2
	} from '@lucide/svelte';
	import { marked } from 'marked';

	let {
		cell,
		index,
		isActive,
		isLast,
		mode,
		onrun,
		onactivate,
		onchange,
		ondelete,
		onmove,
		onaddcell,
		onunrender,
		onopenplot
	}: {
		cell: { id: number; type: 'code' | 'markdown'; content: string; output: string; rendered: boolean; plotSrc?: string };
		index: number;
		isActive: boolean;
		isLast: boolean;
		mode: 'edit' | 'view';
		onrun: () => void;
		onactivate: () => void;
		onchange: (val: string) => void;
		ondelete: () => void;
		onmove: (direction: -1 | 1) => void;
		onaddcell: (type: 'code' | 'markdown', atIndex: number) => void;
		onunrender: () => void;
		onopenplot?: (cellId: number) => void;
	} = $props();
</script>

<div
	class="{mode === 'edit' ? 'group relative' : 'relative'}"
>
	<div class="{mode === 'edit' ? 'py-1.5' : 'py-3'}">
		{#if cell.type === 'markdown' && (mode === 'view' || (cell.rendered && !isActive))}
			<!-- Rendered markdown -->
			{#if mode === 'edit'}
				<div class="relative flex">
					<!-- Left gutter: drag + run -->
					<div class="flex w-10 shrink-0 flex-col items-center pt-3 opacity-0 transition-opacity group-hover:opacity-100">
						<button class="rounded p-0.5 text-muted-foreground/50 hover:text-muted-foreground" title="Drag to reorder" aria-label="Drag to reorder">
							<GripVertical class="size-3.5" />
						</button>
					</div>
					<button
						class="prose prose-invert block w-full min-w-0 max-w-none cursor-text rounded-lg px-4 py-3 text-left transition-colors hover:bg-white/[0.02]"
						onclick={() => { onactivate(); onunrender(); }}
					>
						{@html marked.parse(cell.content)}
					</button>
					<!-- Right gutter: actions -->
					<div class="flex w-10 shrink-0 flex-col items-center gap-0.5 pt-3 opacity-0 transition-opacity group-hover:opacity-100">
						<button class="rounded p-1 text-muted-foreground/60 hover:bg-white/[0.06] hover:text-foreground" title="More actions" aria-label="More actions" onclick={ondelete}>
							<Ellipsis class="size-3.5" />
						</button>
					</div>
				</div>
			{:else}
				<div class="prose prose-invert w-full max-w-none">
					{@html marked.parse(cell.content)}
				</div>
			{/if}
		{:else}
			<!-- Editor / rendered code -->
			<div class="relative flex">
				{#if mode === 'edit'}
					<!-- Left gutter: run button + drag handle -->
					<div class="flex w-10 shrink-0 flex-col items-center gap-1 pt-3">
						<button
							class="flex h-6 w-6 items-center justify-center rounded-md transition-colors {isActive ? 'bg-[oklch(0.55_0.25_265_/_0.15)] text-[oklch(0.75_0.15_265)]' : 'text-muted-foreground/40 hover:bg-white/[0.06] hover:text-muted-foreground'}"
							title="Run cell (Shift+Enter)"
							aria-label="Run cell"
							onclick={onrun}
						>
							<Play class="size-3 {isActive ? '' : 'opacity-0 transition-opacity group-hover:opacity-100'}" />
						</button>
						<button class="rounded p-0.5 text-muted-foreground/30 opacity-0 transition-opacity group-hover:opacity-100 hover:text-muted-foreground" title="Drag to reorder" aria-label="Drag to reorder">
							<GripVertical class="size-3.5" />
						</button>
					</div>
				{/if}

				<!-- Cell body -->
				<div class="min-w-0 flex-1">
					<div class="overflow-hidden rounded-lg bg-[oklch(0.15_0.015_270)] ring-1 transition-all {mode === 'edit' && isActive ? 'ring-[oklch(0.55_0.25_265_/_0.4)]' : 'ring-white/[0.06]'} {mode === 'edit' && !isActive ? 'group-hover:ring-white/[0.1]' : ''} {mode === 'edit' && isActive ? 'shadow-[0_0_20px_-4px_oklch(0.55_0.25_265_/_0.12)]' : ''} p-4">
						{#if mode === 'edit' && isActive}
							<CodeCell
								content={cell.content}
								onchange={(val) => onchange(val)}
								onrun={() => onrun()}
							/>
						{:else if mode === 'edit'}
							<button
								class="block w-full cursor-text text-left"
								onclick={onactivate}
							>
								{#if cell.content}
									<RenderedCode content={cell.content} lang={cell.type === 'code' ? 'python' : 'markdown'} />
								{:else}
									<p class="py-1 text-sm text-muted-foreground/50 italic">Click to edit</p>
								{/if}
							</button>
						{:else}
							{#if cell.content}
								<RenderedCode content={cell.content} lang={cell.type === 'code' ? 'python' : 'markdown'} />
							{/if}
						{/if}
					</div>

					<!-- Output -->
					{#if cell.output}
						<div class="mt-1 px-4 py-3">
							<pre class="whitespace-pre-wrap font-mono text-[14px] leading-relaxed text-foreground/80">{cell.output}</pre>
						</div>
					{/if}

					<!-- Plot thumbnail -->
					{#if cell.plotSrc}
						<div class="mt-2 px-1">
							<button
								class="group/plot relative overflow-hidden rounded-lg border border-white/[0.06] transition-all hover:border-white/[0.12] hover:shadow-lg hover:shadow-black/20"
								onclick={() => onopenplot?.(cell.id)}
							>
								<img
									src={cell.plotSrc}
									alt="Plot output"
									class="block w-full max-h-[200px] object-contain bg-[#1a1b1e]"
								/>
								<div class="absolute inset-0 flex items-center justify-center bg-black/0 transition-colors group-hover/plot:bg-black/30">
									<div class="rounded-lg bg-black/60 p-2 opacity-0 transition-opacity group-hover/plot:opacity-100">
										<Maximize2 class="size-5 text-white" />
									</div>
								</div>
							</button>
						</div>
					{/if}
				</div>

				{#if mode === 'edit'}
					<!-- Right gutter: cell actions -->
					<div class="flex w-10 shrink-0 flex-col items-center gap-0.5 pt-3 opacity-0 transition-opacity group-hover:opacity-100">
						<button class="rounded p-1 text-muted-foreground/50 hover:bg-white/[0.06] hover:text-foreground" title="Move cell up" aria-label="Move cell up" onclick={() => onmove(-1)}>
							<ChevronUp class="size-3.5" />
						</button>
						<button class="rounded p-1 text-muted-foreground/50 hover:bg-white/[0.06] hover:text-foreground" title="Move cell down" aria-label="Move cell down" onclick={() => onmove(1)}>
							<ChevronDownIcon class="size-3.5" />
						</button>
						<button class="rounded p-1 text-muted-foreground/50 hover:bg-destructive/20 hover:text-red-400" title="Delete cell" aria-label="Delete cell" onclick={ondelete}>
							<Trash2 class="size-3.5" />
						</button>
					</div>
				{/if}
			</div>
		{/if}
	</div>

	<!-- Cell divider with insert buttons (edit mode only) -->
	{#if mode === 'edit' && !isLast}
		<div class="group/divider relative flex items-center py-0.5">
			<div class="ml-10 h-px flex-1 bg-white/[0.04] opacity-0 transition-opacity group-hover/divider:opacity-100"></div>
			<div class="flex items-center gap-1 px-2 opacity-0 transition-opacity group-hover/divider:opacity-100">
				<button
					class="flex items-center gap-1 rounded-full border border-white/[0.06] bg-[oklch(0.15_0.015_270)] px-2.5 py-0.5 text-[11px] text-muted-foreground transition-colors hover:border-white/[0.12] hover:text-foreground"
					onclick={() => onaddcell('code', index + 1)}
				>
					<Plus class="size-3" /> Code
				</button>
				<button
					class="flex items-center gap-1 rounded-full border border-white/[0.06] bg-[oklch(0.15_0.015_270)] px-2.5 py-0.5 text-[11px] text-muted-foreground transition-colors hover:border-white/[0.12] hover:text-foreground"
					onclick={() => onaddcell('markdown', index + 1)}
				>
					<Plus class="size-3" /> Markdown
				</button>
			</div>
			<div class="mr-10 h-px flex-1 bg-white/[0.04] opacity-0 transition-opacity group-hover/divider:opacity-100"></div>
		</div>
	{/if}
</div>
