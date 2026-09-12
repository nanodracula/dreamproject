import { encodeBase64 } from 'jsr:@std/encoding@1/base64'

import { generateOpenRouterImage, OpenRouterImageError } from '../_shared/providers/openrouter.ts'
import { measureAsync } from '../_shared/utils/measure-async.ts'
import { createImagePrompt } from './image-prompt.ts'

const imageModel = 'google/gemini-3.1-flash-image'
const corsHeaders = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (request: Request) => {
	if (request.method === 'OPTIONS') {
		return new Response(null, { headers: corsHeaders })
	}

	if (request.method !== 'POST') {
		return jsonError('method_not_allowed', 405)
	}

	let body: unknown
	try {
		body = await request.json()
	} catch {
		return jsonError('invalid_input', 400)
	}

	if (!isImageInput(body)) {
		return jsonError('invalid_input', 400)
	}

	try {
		const prompt = createImagePrompt(body.text.trim(), body.lang.trim(), body.sentence?.trim())
		const { result, durationMs } = await measureAsync(() =>
			generateOpenRouterImage({
				model: imageModel,
				prompt,
				imageSize: '1K',
				aspectRatio: '4:3',
			})
		)
		// JSON with base64 bytes: React Native's fetch cannot parse multipart responses.
		// TODO: switch to Hono, or to a raw binary body with metadata in a header
		// read by a hand-rolled fetch + arrayBuffer() on the client, to avoid the
		// base64 overhead.
		return Response.json(
			{
				contentType: result.contentType,
				base64: encodeBase64(result.bytes),
				metadata: {
					type: 'image',
					durationMs,
					model: imageModel,
					prompt,
				},
			},
			{ headers: corsHeaders },
		)
	} catch (error) {
		console.error('[generate-image]', error)
		if (error instanceof OpenRouterImageError) {
			if (error.code === 'missing_api_key') {
				return jsonError('server_misconfigured', 500)
			}
			if (error.code === 'no_image') {
				return jsonError('image_empty', 502)
			}
		}
		return jsonError('image_failed', 502)
	}
})

function isImageInput(value: unknown): value is { text: string; lang: string; sentence?: string } {
	if (!value || typeof value !== 'object') {
		return false
	}

	const input = value as Record<string, unknown>
	return (
		typeof input.text === 'string' &&
		input.text.trim().length > 0 &&
		input.text.length <= 500 &&
		typeof input.lang === 'string' &&
		input.lang.trim().length > 0 &&
		(input.sentence === undefined ||
			(typeof input.sentence === 'string' && input.sentence.length <= 1_000))
	)
}

function jsonError(code: string, status: number) {
	return Response.json(
		{ code },
		{
			status,
			headers: corsHeaders,
		},
	)
}
