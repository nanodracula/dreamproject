export function formatPrompt(
	strings: TemplateStringsArray,
	...values: unknown[]
): string {
	const raw = strings.reduce((result, part, index) => {
		const value = index < values.length ? String(values[index] ?? '') : ''
		return result + part + value
	}, '')

	return normalizePromptWhitespace(raw)
}

function normalizePromptWhitespace(text: string): string {
	const lines = text.replace(/\r\n/g, '\n').split('\n')

	while (lines.length > 0 && lines[0].trim() === '') {
		lines.shift()
	}

	while (lines.length > 0 && lines[lines.length - 1].trim() === '') {
		lines.pop()
	}

	if (lines.length === 0) {
		return ''
	}

	const nonEmptyLines = lines.filter((line) => line.trim() !== '')
	const minIndent = Math.min(
		...nonEmptyLines.map((line) => line.match(/^[\t ]*/)![0].length),
	)
	const cleanedLines = lines.map((line) => {
		const dedented = line.trim() === '' ? '' : line.slice(minIndent)
		return dedented.replace(/[ \t]+$/g, '')
	})

	return cleanedLines.join('\n').replace(/\n{3,}/g, '\n\n')
}
