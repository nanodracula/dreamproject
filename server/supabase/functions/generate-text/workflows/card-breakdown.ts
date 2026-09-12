import { z } from 'npm:zod@4.5.4'

import { sentenceBreakdownSchema } from '../../_shared/contracts/database.ts'

const inputSchema = z.strictObject({
	text: z.string().trim().min(1).max(2_000),
	sourceLanguage: z.string().trim().min(2).max(16),
	explanationLanguage: z.string().trim().min(2).max(16),
})

const cardBreakdownOutputSchema = sentenceBreakdownSchema.extend({
	items: sentenceBreakdownSchema.shape.items.min(1).max(100),
})

export const cardBreakdownWorkflow = {
	type: 'card-breakdown',
	schemaName: 'card_breakdown',
	outputSchema: cardBreakdownOutputSchema,
	inputSchema,
	createPrompt(_input: z.infer<typeof inputSchema>) {
		// TODO: Write the card-breakdown prompts.
		return {
			systemPrompt: null,
			userPrompt: 'TODO',
		}
	},
} as const
