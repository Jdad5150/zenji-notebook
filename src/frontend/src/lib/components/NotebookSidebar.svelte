<script lang="ts">
	import { FileText, Folder, ChevronRight, PanelLeftClose, PanelLeftOpen } from '@lucide/svelte';
	import { goto } from '$app/navigation';

	let {
		open = true,
		ontoggle
	}: {
		open?: boolean;
		ontoggle: () => void;
	} = $props();
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
				<button
					class="flex w-full items-center gap-2 rounded-md px-2.5 py-1.5 text-[0.8125rem] text-foreground/70 transition-colors hover:bg-white/4 hover:text-foreground"
				>
					<ChevronRight class="size-3.5 text-muted-foreground/40" />
					<Folder class="size-4 text-[oklch(0.75_0.15_265/0.7)]" />
					<span>data</span>
				</button>
				<button
					class="flex w-full items-center gap-2 rounded-md px-2.5 py-1.5 text-[0.8125rem] text-foreground/70 transition-colors hover:bg-white/4 hover:text-foreground"
				>
					<ChevronRight class="size-3.5 text-muted-foreground/40" />
					<Folder class="size-4 text-[oklch(0.75_0.15_265/0.7)]" />
					<span>models</span>
				</button>
				<button
					class="flex w-full items-center gap-2 rounded-md bg-white/6 px-2.5 py-1.5 text-[0.8125rem] text-foreground"
				>
					<span class="w-3.5"></span>
					<FileText class="size-4 text-[oklch(0.75_0.12_200)]" />
					<span>Untitled.znb</span>
				</button>
				<button
					class="flex w-full items-center gap-2 rounded-md px-2.5 py-1.5 text-[0.8125rem] text-foreground/70 transition-colors hover:bg-white/4 hover:text-foreground"
				>
					<span class="w-3.5"></span>
					<FileText class="size-4 text-muted-foreground/40" />
					<span>analysis.znb</span>
				</button>
				<button
					class="flex w-full items-center gap-2 rounded-md px-2.5 py-1.5 text-[0.8125rem] text-foreground/70 transition-colors hover:bg-white/4 hover:text-foreground"
				>
					<span class="w-3.5"></span>
					<FileText class="size-4 text-muted-foreground/40" />
					<span>README.md</span>
				</button>
			</div>
		</div>
	{/if}
</div>
