<script lang="ts">
	import { onMount } from 'svelte';
	import {
		EditorView,
		keymap,
		lineNumbers,
		highlightActiveLine,
		highlightActiveLineGutter
	} from '@codemirror/view';
	import { EditorState } from '@codemirror/state';
	import { defaultKeymap, indentWithTab } from '@codemirror/commands';
	import { python } from '@codemirror/lang-python';
	import { catppuccinHighlight } from './catppuccin-highlight';
	import { bracketMatching, indentOnInput, StreamLanguage } from '@codemirror/language';
	import { r as rLang } from '@codemirror/legacy-modes/mode/r';
	import { julia as juliaLang } from '@codemirror/legacy-modes/mode/julia';
	import { closeBrackets } from '@codemirror/autocomplete';

	function langExtension(lang: string) {
		if (lang === 'r') return StreamLanguage.define(rLang);
		if (lang === 'julia') return StreamLanguage.define(juliaLang);
		return python(); // python and mojo both use Python grammar
	}

	let {
		content = '',
		lang = 'python',
		onchange,
		onrun
	}: {
		content?: string;
		lang?: string;
		onchange?: (value: string) => void;
		onrun?: () => void;
	} = $props();

	let container: HTMLDivElement;
	let view: EditorView;

	const zenjiTheme = EditorView.theme({
		'&': {
			fontSize: '14px',
			backgroundColor: 'transparent'
		},
		'.cm-content': {
			fontFamily: '"Lilex Variable", ui-monospace, monospace',
			padding: '8px 0'
		},
		'.cm-gutters': {
			backgroundColor: 'transparent',
			border: 'none',
			color: 'oklch(0.5 0.015 270)'
		},
		'.cm-activeLineGutter': {
			backgroundColor: 'transparent'
		},
		'.cm-activeLine': {
			backgroundColor: 'oklch(1 0 270 / 0.03)'
		},
		'.cm-cursor, .cm-dropCursor': {
			borderLeftColor: 'oklch(0.91 0.008 265)'
		},
		'&.cm-focused .cm-cursor': {
			borderLeftColor: 'oklch(0.91 0.008 265)'
		},
		'.cm-selectionBackground': {
			backgroundColor: 'oklch(0.55 0.15 265 / 0.15) !important'
		},
		'&.cm-focused .cm-selectionBackground': {
			backgroundColor: 'oklch(0.55 0.15 265 / 0.15) !important'
		},
		'.cm-matchingBracket': {
			backgroundColor: 'oklch(0.55 0.15 265 / 0.12)',
			outline: 'none'
		}
	}, { dark: true });

	onMount(() => {
		const runKeymap = keymap.of([
			{
				key: 'Shift-Enter',
				run: () => {
					onrun?.();
					return true;
				}
			}
		]);

		const updateListener = EditorView.updateListener.of((update) => {
			if (update.docChanged) {
				onchange?.(update.state.doc.toString());
			}
		});

		view = new EditorView({
			state: EditorState.create({
				doc: content,
				extensions: [
					lineNumbers(),
					highlightActiveLine(),
					highlightActiveLineGutter(),
					bracketMatching(),
					closeBrackets(),
					indentOnInput(),
					langExtension(lang),
					catppuccinHighlight,
					zenjiTheme,
					keymap.of([...defaultKeymap, indentWithTab]),
					runKeymap,
					updateListener,
					EditorView.lineWrapping
				]
			}),
			parent: container
		});

		return () => view.destroy();
	});
</script>

<div bind:this={container} class="cm-wrapper"></div>

<style>
	.cm-wrapper :global(.cm-editor) {
		outline: none;
	}
	.cm-wrapper :global(.cm-editor.cm-focused) {
		outline: none;
	}
</style>
