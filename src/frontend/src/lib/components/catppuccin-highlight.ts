import { HighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { tags } from '@lezer/highlight';
import { flavors } from '@catppuccin/palette';

const c = flavors.mocha.colors;

export const catppuccinHighlight = syntaxHighlighting(
	HighlightStyle.define([
		{ tag: tags.keyword, color: c.mauve.hex },
		{
			tag: [tags.name, tags.definition(tags.name), tags.deleted, tags.character, tags.macroName],
			color: c.text.hex
		},
		{
			tag: [
				tags.function(tags.variableName),
				tags.function(tags.propertyName),
				tags.propertyName,
				tags.labelName
			],
			color: c.blue.hex
		},
		{ tag: [tags.color, tags.constant(tags.name), tags.standard(tags.name)], color: c.peach.hex },
		{ tag: [tags.self, tags.atom], color: c.red.hex },
		{
			tag: [tags.typeName, tags.className, tags.changed, tags.annotation, tags.namespace],
			color: c.yellow.hex
		},
		{ tag: [tags.operator], color: c.sky.hex },
		{ tag: [tags.url, tags.link], color: c.teal.hex },
		{ tag: [tags.escape, tags.regexp], color: c.pink.hex },
		{ tag: [tags.meta, tags.punctuation, tags.separator, tags.comment], color: c.overlay2.hex },
		{ tag: tags.strong, fontWeight: 'bold' },
		{ tag: tags.emphasis, fontStyle: 'italic' },
		{ tag: tags.strikethrough, textDecoration: 'line-through' },
		{ tag: tags.link, color: c.blue.hex, textDecoration: 'underline' },
		{ tag: tags.heading, fontWeight: 'bold', color: c.blue.hex },
		{ tag: [tags.special(tags.variableName)], color: c.lavender.hex },
		{ tag: [tags.bool, tags.number], color: c.peach.hex },
		{ tag: [tags.processingInstruction, tags.string, tags.inserted], color: c.green.hex },
		{ tag: tags.invalid, color: c.red.hex }
	])
);
