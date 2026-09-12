import { z } from 'npm:zod@4.5.4'

import { formatPrompt as clearFormatting } from '../../_shared/utils/format-prompt.ts'

/**
 * Learning languages the request accepts. The Swift language catalog keeps its own copy;
 * adding a language edits both. Codes without an entry in `languageNotes` get no extra guidance.
 */
export const learningLanguageCodes = ['ja', 'zh-Hant', 'ko', 'pl', 'uk'] as const
export type LearningLanguageCode = (typeof learningLanguageCodes)[number]

export const cardTitleTones = ['formal', 'polite', 'casual', 'slang'] as const
export type CardTitleTone = (typeof cardTitleTones)[number]

export const cardTitleInputSchema = z.strictObject({
	inputText: z.string().trim().min(1).max(2_000),
	learningLanguageCode: z.enum(learningLanguageCodes),
	nativeLanguage: z.string().trim().min(1).max(100),
	/** Language and script description for the prompt, e.g. "Japanese (Kanji and kana)". */
	nativeWritingSystem: z.string().trim().min(1).max(200),
	userKnowledgeLevel: z.string().trim().min(1).max(100),
})
export type CardTitleInput = z.infer<typeof cardTitleInputSchema>

export const cardTitleVariantSchema = z.strictObject({
	title: z.string().trim().min(1).max(500),
	translation: z.string().trim().min(1).max(1_000),
	contentType: z.enum(['word', 'sentence']),
	sentenceType: z.enum(['question', 'sentence', 'phrase']).nullable(),
	tone: z.enum(cardTitleTones),
	recommended: z.boolean(),
	info: z.strictObject({
		desc: z.string().trim().min(1).max(1_000),
	}),
})
export type CardTitleVariant = z.infer<typeof cardTitleVariantSchema>

export const cardTitleOutputSchema = z.strictObject({
	titleVariants: z.array(cardTitleVariantSchema).min(1).max(4),
})
export type CardTitleOutput = z.infer<typeof cardTitleOutputSchema>

/** Renders a string literal list as a TS-style union for the prompt: `'a' | 'b'`. */
function union(values: readonly string[]) {
	return values.map((value) => `'${value}'`).join(' | ')
}

/** Extra guidance keyed by the learning language code. */
const languageNotes: Partial<Record<LearningLanguageCode, string>> = {
	ja: clearFormatting`
		- Write 'title' in native kanji and kana, never in romaji: "ocha" -> "お茶" (not "ocha").
		- If the input is already contains Japanese in romaji, keep the exact wording and only convert the script: "gaijin" must become "外人", not "外国人".
		- For Japanese sentences, aim for one variant per tone ('formal', 'polite', 'casual', 'slang'), but only if it's natural and commonly used — skip a tone rather than force it.
	`,
}

function titleSystemPrompt({
	learningLanguageCode,
	nativeLanguage,
	nativeWritingSystem,
	userKnowledgeLevel,
}: Omit<CardTitleInput, 'inputText'>) {
	void userKnowledgeLevel // Don't remove!

	// The request describes the learning language together with its script, e.g.
	// "Japanese (Kanji and kana)"; the prompt uses that description as the language name.
	const learningLanguage = nativeWritingSystem

	const prompt = clearFormatting`
		You need to process user 'input' into a learning language flashcard title (${learningLanguage}) and translation (${nativeLanguage}).

		# Title writing system (critical)

		- Always write 'title' in the native writing system: ${nativeWritingSystem}. Never use romanization, phonetic spelling, transliteration etc. — convert to native writing if needed.
		- If the input already contains ${learningLanguage}, preserve its exact wording and change only its writing system — never substitute words.

		# Logic

		1) If 'input' has only ${learningLanguage} side:
			- Translate it to ${nativeLanguage}.
			- Return 1 item in array.

		2) If 'input' is not ${learningLanguage}, treat it as text to translate into ${learningLanguage}:
			- If there is one obvious common way to say it in ${learningLanguage}, return 1 item in array.
			- If there are a few natural ways to say it, return 1-4 variants. The recommended natural way must be first in the list. For sentences, usually 3+ variants are recommended, including the shortest universal natural way of saying it that would be easy for a learner to remember.

		3) If 'input' has both a ${learningLanguage} side and its meaning:
				- Use the ${learningLanguage} side as 'title' and the given meaning as 'translation' (in ${nativeLanguage}).
				- Return 1 item in array.

		# Classification

		-	Only a single word is contentType 'word'. Multi-word phrases are contentType 'sentence' with sentenceType 'phrase'.
		- 'sentenceType' classification rules:
			If interrogative          → question
			Otherwise, if complete    → sentence
			Otherwise                 → phrase
	`

	const outputFormat = clearFormatting`
		# JSON output format:

		{
			titleVariants: [
				{
					title: string // (in ${learningLanguage}, in its native writing system),
					translation: string // (in ${nativeLanguage}),
					contentType: 'word' | 'sentence',
					sentenceType: 'question' | 'sentence' | 'phrase' | null, // (null if contentType is 'word')
					tone: ${union(cardTitleTones)},
					recommended: boolean, // (true for exactly one variant, the first)
					info: {
						desc: string // (concise, 4-12 words, in ${nativeLanguage}: what distinguishes this variant from the others — nuance, typical situation, who says it etc.)
					}
				},
				...
			]
		}
	`

	const notes = languageNotes[learningLanguageCode]

	return [prompt, notes && `# ${learningLanguage} specifics\n\n${notes}`, outputFormat]
		.filter(Boolean)
		.join('\n\n')
}

function titleUserPrompt(inputText: string) {
	return clearFormatting`
		# Input text:

		"""${inputText}"""
	`
}

export const cardTitleWorkflow = {
	type: 'card-title',
	schemaName: 'card_title',
	outputSchema: cardTitleOutputSchema,
	inputSchema: cardTitleInputSchema,
	createPrompt(input: CardTitleInput) {
		return {
			systemPrompt: titleSystemPrompt(input),
			userPrompt: titleUserPrompt(input.inputText),
		}
	},
} as const
