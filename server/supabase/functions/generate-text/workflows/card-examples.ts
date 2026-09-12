import { z } from 'npm:zod@4.5.4'

import { formatPrompt as clearFormatting } from '../../_shared/utils/format-prompt.ts'

const inputSchema = z.strictObject({
	title: z.string().trim().min(1).max(500),
	translation: z.string().trim().min(1).max(1_000),
	learningLanguage: z.string().trim().min(1).max(100),
	nativeLanguage: z.string().trim().min(1).max(100),
	userKnowledgeLevel: z.string().trim().min(1).max(100),
	customSentenceInput: z.string().trim().min(1).max(2_000),
})

const cardExamplesOutputSchema = z.strictObject({
	sentenceVariants: z.array(
		z.strictObject({
			sentence: z.string().trim().min(1).max(2_000),
			sentenceTranslation: z.string().trim().min(1).max(2_000),
			info: z.strictObject({
				desc: z.string().trim().min(1).max(500),
			}),
		}),
	).length(1),
})

type CardExamplesInput = z.infer<typeof inputSchema>

function customSentenceSystemPrompt({
	learningLanguage,
	nativeLanguage,
	userKnowledgeLevel,
}: Pick<CardExamplesInput, 'learningLanguage' | 'nativeLanguage' | 'userKnowledgeLevel'>) {
	return clearFormatting`
		Generate 1 natural example sentence in ${learningLanguage} from the learner's custom sentence idea. The learner's native language is ${nativeLanguage}, and their level is ${userKnowledgeLevel}.

		# JSON output format:

		{
			"sentenceVariants": [
				{
					"sentence": string,
					"sentenceTranslation": string,
					"info": { "desc": string }
				}
			]
		}

		# Requirements:
		- Return exactly 1 sentence variant.
		- If the custom idea is already a complete natural sentence in ${learningLanguage}, use it as "sentence" with only minimal cleanup for punctuation or obvious typos.
		- The custom idea may be written in any language. Convert its intended meaning into natural, native-script, conversational ${learningLanguage}.
		- The sentence MUST feature the target word/phrase from the user message as its main focus.
		- Natural inflection is required and welcome: cases, conjugation, gender, number, particles, tense and other grammatical changes are allowed and encouraged when the language demands it. Do not force the dictionary form.
		- Keep the sentence short and clear: roughly 5-12 words. Avoid idiomatic complexity above ${userKnowledgeLevel} level.
		- "sentence" is in ${learningLanguage} written in its natural native script.
		- "sentenceTranslation" is a faithful translation in ${nativeLanguage}.
		- "info.desc" is a super short (4-7 words) ${nativeLanguage} description of the context.
		- Output ONLY the JSON object, no commentary.
	`
}

function customSentenceUserPrompt({
	title,
	translation,
	customSentenceInput,
}: Pick<CardExamplesInput, 'title' | 'translation' | 'customSentenceInput'>) {
	return clearFormatting`
		# Target word/phrase:

		title: "${title}"
		translation: "${translation}"

		# Learner's custom sentence idea:

		${customSentenceInput}
	`
}

export const cardExamplesWorkflow = {
	type: 'card-examples',
	schemaName: 'card_examples',
	outputSchema: cardExamplesOutputSchema,
	inputSchema,
	createPrompt(input: CardExamplesInput) {
		return {
			systemPrompt: customSentenceSystemPrompt(input),
			userPrompt: customSentenceUserPrompt(input),
		}
	},
} as const
