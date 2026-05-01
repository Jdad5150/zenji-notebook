<script lang="ts">
	import { onMount } from 'svelte';
	import { createHighlighter, type Highlighter } from 'shiki';
	import catppuccinMocha from 'shiki/themes/catppuccin-mocha.mjs';

	let {
		content = '',
		lang = 'python'
	}: {
		content?: string;
		lang?: string;
	} = $props();

	let html = $state('');

	// Patch the theme: remap Python built-in functions from peach (#fab387) to
	// blue (#89b4fa) with italic, matching CodeMirror's lezer mapping
	// (function(variableName) → blue). The upstream theme has a specific rule
	// for `support.function.builtin.python` that we need to mutate in-place.
	const patchedTheme = {
		...catppuccinMocha,
		tokenColors: (catppuccinMocha.tokenColors ?? []).map((tc) => {
			const scopes = Array.isArray(tc.scope) ? tc.scope : [tc.scope];
			if (scopes.includes('support.function.builtin.python')) {
				return {
					...tc,
					scope: scopes.filter((s) => s !== 'support.function.builtin.python'),
					settings: { ...tc.settings }
				};
			}
			return tc;
		}).concat({
			scope: ['support.function.builtin.python'],
			settings: { foreground: '#89b4fa', fontStyle: 'italic' }
		})
	};

	// Shared highlighter — created once, reused across all RenderedCode instances
	let highlighterPromise: Promise<Highlighter> | null = null;

	function getHighlighter(): Promise<Highlighter> {
		if (!highlighterPromise) {
			highlighterPromise = createHighlighter({
				themes: [patchedTheme],
				langs: ['python', 'markdown']
			});
		}
		return highlighterPromise;
	}

	async function highlight(code: string, language: string) {
		const highlighter = await getHighlighter();

		const loaded = highlighter.getLoadedLanguages();
		if (!loaded.includes(language as any)) {
			await highlighter.loadLanguage(language as any);
		}

		html = highlighter.codeToHtml(code, {
			lang: language,
			theme: 'catppuccin-mocha'
		});
	}

	onMount(() => {
		highlight(content, lang);
	});

	$effect(() => {
		highlight(content, lang);
	});
</script>

{#if html}
	<div class="rendered-code">{@html html}</div>
{:else}
	<pre class="rendered-code-fallback">{content}</pre>
{/if}

<style>
	.rendered-code :global(pre) {
		margin: 0;
		padding: 8px 0;
		background: transparent !important;
		font-family: 'Lilex Variable', ui-monospace, monospace;
		font-size: 14px;
		line-height: 1.5;
	}

	.rendered-code :global(code) {
		font-family: inherit;
		font-size: inherit;
		line-height: inherit;
	}

	.rendered-code :global(.shiki) {
		background: transparent !important;
	}

	.rendered-code-fallback {
		margin: 0;
		padding: 8px 0;
		background: transparent;
		font-family: 'Lilex Variable', ui-monospace, monospace;
		font-size: 14px;
		line-height: 1.5;
		color: oklch(0.91 0.008 265);
		white-space: pre-wrap;
	}
</style>
