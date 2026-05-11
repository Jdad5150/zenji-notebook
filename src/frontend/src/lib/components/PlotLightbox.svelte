<script lang="ts">
	import { X, ChevronLeft, ChevronRight, Download, ExternalLink } from '@lucide/svelte';
	import { onMount } from 'svelte';

	let {
		plots,
		currentIndex,
		onclose,
		onnavigate
	}: {
		plots: { cellId: number; src: string; title: string }[];
		currentIndex: number;
		onclose: () => void;
		onnavigate: (index: number) => void;
	} = $props();

	let current = $derived(plots[currentIndex]);
	let hasPrev = $derived(currentIndex > 0);
	let hasNext = $derived(currentIndex < plots.length - 1);

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onclose();
		if (e.key === 'ArrowLeft' && hasPrev) onnavigate(currentIndex - 1);
		if (e.key === 'ArrowRight' && hasNext) onnavigate(currentIndex + 1);
	}

	onMount(() => {
		document.addEventListener('keydown', handleKeydown);
		return () => document.removeEventListener('keydown', handleKeydown);
	});
</script>

<!-- Backdrop -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm"
	onmousedown={(e) => {
		if (e.target === e.currentTarget) onclose();
	}}
>
	<!-- Lightbox container -->
	<div
		class="relative flex h-[92vh] w-[92vw] flex-col overflow-hidden rounded-xl border border-white/8 bg-[oklch(0.17_0.015_270)] shadow-2xl"
	>
		<!-- Header -->
		<div class="flex shrink-0 items-center justify-between border-b border-white/6 px-4 py-2.5">
			<div class="flex items-center gap-3">
				<span class="text-[0.8125rem] text-foreground">{current.title}</span>
				<span class="font-mono text-[0.6875rem] text-muted-foreground"
					>{currentIndex + 1} / {plots.length}</span
				>
			</div>
			<div class="flex items-center gap-1">
				<button
					class="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-white/6 hover:text-foreground"
					title="Download plot"
					aria-label="Download plot"
				>
					<Download class="size-4" />
				</button>
				<button
					class="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-white/6 hover:text-foreground"
					title="Open in new window"
					aria-label="Open in new window"
				>
					<ExternalLink class="size-4" />
				</button>
				<button
					class="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-white/6 hover:text-foreground"
					title="Close (Esc)"
					aria-label="Close"
					onclick={onclose}
				>
					<X class="size-4" />
				</button>
			</div>
		</div>

		<!-- Plot -->
		<div class="flex flex-1 items-center justify-center overflow-auto p-6">
			<img
				src={current.src}
				alt={current.title}
				class="max-h-full max-w-full rounded object-contain"
			/>
		</div>

		<!-- Navigation -->
		{#if plots.length > 1}
			<div
				class="border-white/6px-4 flex shrink-0 items-center justify-center gap-4 border-t py-2.5"
			>
				<button
					class="flex items-center gap-1.5 rounded-md px-3 py-1 text-[0.8125rem] transition-colors {hasPrev
						? 'text-foreground/80 hover:bg-white/6'
						: 'cursor-default text-muted-foreground/30'}"
					onclick={() => hasPrev && onnavigate(currentIndex - 1)}
					disabled={!hasPrev}
				>
					<ChevronLeft class="size-4" />
					Previous
				</button>

				<!-- Thumbnail strip -->
				<div class="flex items-center gap-1.5">
					{#each plots as plot, i (plot.cellId)}
						<button
							class="h-10 w-14 overflow-hidden rounded border transition-all {i === currentIndex
								? 'border-[oklch(0.55_0.25_265/0.5)] ring-1 ring-[oklch(0.55_0.25_265/0.3)]'
								: 'border-white/6 hover:border-white/15'}"
							onclick={() => onnavigate(i)}
						>
							<img src={plot.src} alt={plot.title} class="h-full w-full object-cover" />
						</button>
					{/each}
				</div>

				<button
					class="flex items-center gap-1.5 rounded-md px-3 py-1 text-[0.8125rem] transition-colors {hasNext
						? 'text-foreground/80 hover:bg-white/6'
						: 'cursor-default text-muted-foreground/30'}"
					onclick={() => hasNext && onnavigate(currentIndex + 1)}
					disabled={!hasNext}
				>
					Next
					<ChevronRight class="size-4" />
				</button>
			</div>
		{/if}
	</div>
</div>
