import { formatPrompt as clearFormatting } from '../_shared/utils/format-prompt.ts'

const realisticStyle = `
	Style: realistic editorial photography, natural proportions,
	believable materials, subtle textures, and lifelike skin.
	No illustration, anime, cartoon, or 3D rendering.

	Color: subdued natural colors, balanced whites, gentle contrast.
	Lighting: soft natural light appropriate to the scene.
	Composition: one clear subject, simple surroundings, readable at small sizes.
`

const koreanStyle = `
	${realisticStyle}
	Mood: quiet contemporary Korean cinema.
	Color: subdued cool tones with natural skin tones.
	When relevant, use everyday South Korean settings and objects.
`

const taiwaneseStyle = `
	${realisticStyle}
	Mood: relaxed Taiwanese everyday-life photography.
	Color: soft greens, warm neutrals, gentle daylight.
	When relevant, use everyday Taiwanese settings and objects.
`

const japaneseAnimeStyle = `
		Style: clean 2D Japanese anime, crisp dark blue-gray linework, grounded proportions, subtle cel shading, smooth surfaces, polished anime film-frame rendering.

		Color: distinctly cool blue-tinted, dominated by muted blue-gray, slate blue, navy, and subtle cyan, while still preserving subdued natural browns, creams, greens, and grays. Use realistic skin tones when people are needed. Blue atmosphere, not monochrome blue. No yellow or amber cast.

		Lighting: soft cool nighttime ambient light, neutral-to-cool white practical lights, deeper blue shadows, natural-color highlights.

		Mood: calm, quiet, introspective, slightly nostalgic.
`

const stylesByLanguage = new Map([
	['ja', japaneseAnimeStyle],
	['ko', koreanStyle],
	['zh-Hant', taiwaneseStyle],
])

export function createImagePrompt(text: string, lang: string, sentence?: string): string {
	const style = stylesByLanguage.get(lang) ?? realisticStyle

	return clearFormatting`
		Subject: a single clear scene that conveys the meaning of "${text}" in language "${lang}" so a language learner recognizes it at a glance.${
		sentence ? ` Usage example: "${sentence}".` : ''
	}

		Prioritize the meaning and usage context.
		Focus on the subject itself; include people only when needed to convey the meaning or usage.
		For abstract meanings, depict a concrete everyday situation.
		Preserve culturally specific objects when relevant.

		Do not include text: no letters, captions, logos, or watermarks anywhere in the image.

		${style}
	`
}
