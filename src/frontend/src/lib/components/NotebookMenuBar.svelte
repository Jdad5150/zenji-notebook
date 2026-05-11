<script lang="ts">
	import { onMount } from 'svelte';

	type MenuItem = { label: string; shortcut?: string; disabled?: boolean } | 'separator';

	type Menu = {
		label: string;
		items: MenuItem[];
	};

	const menus: Menu[] = [
		{
			label: 'File',
			items: [
				{ label: 'New Notebook', shortcut: 'Ctrl+N' },
				{ label: 'Open…', shortcut: 'Ctrl+O' },
				'separator',
				{ label: 'Save', shortcut: 'Ctrl+S' },
				{ label: 'Save As…', shortcut: 'Ctrl+Shift+S' },
				{ label: 'Export as Python (.py)' },
				{ label: 'Export as HTML' },
				'separator',
				{ label: 'Close Notebook', shortcut: 'Ctrl+W' }
			]
		},
		{
			label: 'Edit',
			items: [
				{ label: 'Undo', shortcut: 'Ctrl+Z' },
				{ label: 'Redo', shortcut: 'Ctrl+Shift+Z' },
				'separator',
				{ label: 'Cut Cell', shortcut: 'Ctrl+X' },
				{ label: 'Copy Cell', shortcut: 'Ctrl+C' },
				{ label: 'Paste Cell Below', shortcut: 'Ctrl+V' },
				{ label: 'Delete Cell', shortcut: 'Ctrl+Backspace' },
				'separator',
				{ label: 'Select All Cells', shortcut: 'Ctrl+Shift+A' },
				{ label: 'Find & Replace', shortcut: 'Ctrl+H' }
			]
		},
		{
			label: 'View',
			items: [
				{ label: 'Toggle Sidebar', shortcut: 'Ctrl+B' },
				{ label: 'Toggle Data Explorer', shortcut: 'Ctrl+J' },
				'separator',
				{ label: 'Collapse All Cells' },
				{ label: 'Expand All Cells' },
				'separator',
				{ label: 'Zoom In', shortcut: 'Ctrl+=' },
				{ label: 'Zoom Out', shortcut: 'Ctrl+-' },
				{ label: 'Reset Zoom', shortcut: 'Ctrl+0' }
			]
		},
		{
			label: 'Run',
			items: [
				{ label: 'Run Cell', shortcut: 'Shift+Enter' },
				{ label: 'Run Cell & Advance', shortcut: 'Alt+Enter' },
				{ label: 'Run All', shortcut: 'Ctrl+Shift+Enter' },
				'separator',
				{ label: 'Run All Above' },
				{ label: 'Run All Below' },
				'separator',
				{ label: 'Interrupt Kernel' },
				{ label: 'Restart Kernel' },
				{ label: 'Restart & Run All' }
			]
		},
		{
			label: 'Settings',
			items: [
				{ label: 'Theme', disabled: true },
				{ label: 'Key Bindings', disabled: true },
				'separator',
				{ label: 'Editor Font Size' },
				{ label: 'Line Numbers' },
				{ label: 'Word Wrap' },
				'separator',
				{ label: 'Notebook Settings…' }
			]
		},
		{
			label: 'Help',
			items: [
				{ label: 'Keyboard Shortcuts', shortcut: 'Ctrl+/' },
				{ label: 'Documentation' },
				'separator',
				{ label: 'About Zenji' }
			]
		}
	];

	let openMenu = $state<string | null>(null);
	let menuBarEl: HTMLDivElement;

	function toggleMenu(label: string) {
		openMenu = openMenu === label ? null : label;
	}

	function hoverMenu(label: string) {
		if (openMenu !== null) {
			openMenu = label;
		}
	}

	function handleClickOutside(e: MouseEvent) {
		if (openMenu && menuBarEl && !menuBarEl.contains(e.target as Node)) {
			openMenu = null;
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			openMenu = null;
		}
	}

	onMount(() => {
		document.addEventListener('click', handleClickOutside);
		document.addEventListener('keydown', handleKeydown);
		return () => {
			document.removeEventListener('click', handleClickOutside);
			document.removeEventListener('keydown', handleKeydown);
		};
	});
</script>

<div class="flex items-center gap-0 px-4 pb-1" bind:this={menuBarEl}>
	{#each menus as menu (menu.label)}
		<div class="relative">
			<button
				class="rounded-md px-2.5 py-0.5 text-[0.8125rem] transition-colors {openMenu === menu.label
					? 'bg-white/8 text-foreground'
					: 'text-muted-foreground/70 hover:bg-white/6 hover:text-foreground'}"
				onclick={() => toggleMenu(menu.label)}
				onmouseenter={() => hoverMenu(menu.label)}
			>
				{menu.label}
			</button>

			{#if openMenu === menu.label}
				<div
					class="absolute top-full left-0 z-50 mt-1 min-w-55 overflow-hidden rounded-lg border border-white/8 bg-[oklch(0.19_0.015_270)] p-1 shadow-xl shadow-black/30"
				>
					{#each menu.items as item (item)}
						{#if item === 'separator'}
							<div class="my-1 h-px bg-white/6"></div>
						{:else}
							<button
								class="flex w-full items-center justify-between rounded-md px-3 py-1.5 text-left text-[0.8125rem] transition-colors {item.disabled
									? 'cursor-default text-muted-foreground/30'
									: 'text-foreground/80 hover:bg-white/6 hover:text-foreground'}"
								onclick={() => {
									if (!item.disabled) openMenu = null;
								}}
								disabled={item.disabled}
							>
								<span>{item.label}</span>
								{#if item.shortcut}
									<span class="ml-6 font-mono text-[0.6875rem] text-muted-foreground/40"
										>{item.shortcut}</span
									>
								{/if}
							</button>
						{/if}
					{/each}
				</div>
			{/if}
		</div>
	{/each}
</div>
