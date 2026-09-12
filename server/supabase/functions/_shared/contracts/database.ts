// Database contracts used by the edge functions. Enum values mirror the SQL
// enums in ../../../schemas/00_types.sql; Swift payload types are maintained
// separately (docs/plans/03-content-storage.md). Adding a value edits both.
import { z } from 'npm:zod@4.5.4'

/**
 * Universal Dependencies v2 POS tags.
 * @see https://universaldependencies.org/u/pos/index.html
 */
export const partsOfSpeech = [
	'ADJ',
	'ADP',
	'ADV',
	'AUX',
	'CCONJ',
	'DET',
	'INTJ',
	'NOUN',
	'NUM',
	'PART',
	'PRON',
	'PROPN',
	'PUNCT',
	'SCONJ',
	'SYM',
	'VERB',
	'X',
] as const

export const audioPaces = ['slow', 'normal', 'fast'] as const
export type AudioPace = (typeof audioPaces)[number]

export const frequencyRanks = [100, 200, 500, 1000, 2000, 5000, 10000, 20000] as const
export type FrequencyRank = (typeof frequencyRanks)[number]

export const sentenceBreakdownWordSchema = z.strictObject({
	type: z.literal('word'),

	partOfSpeech: z.enum(partsOfSpeech).exclude(['PUNCT']),

	originalChunk: z.string().min(1),
	baseForm: z.string().min(1),

	frequencyRank: z.literal(frequencyRanks).nullable(),

	details: z.string().min(1),
	translationInContext: z.string().min(1),

	otherTranslations: z.array(z.string().min(1)),

	writingPhonetic: z.string().min(1).nullable(),
	writingTransliterated: z.string().min(1),
})

export const sentenceBreakdownPunctuationSchema = z.strictObject({
	type: z.literal('punctuation'),
	partOfSpeech: z.literal('PUNCT'),

	originalChunk: z.string().min(1),
	details: z.string().min(1),
})

export const sentenceBreakdownSchema = z.strictObject({
	schemaVersion: z.literal(1),

	items: z.array(
		z.discriminatedUnion('type', [
			sentenceBreakdownWordSchema,
			sentenceBreakdownPunctuationSchema,
		]),
	),
})
export type SentenceBreakdown = z.infer<typeof sentenceBreakdownSchema>
