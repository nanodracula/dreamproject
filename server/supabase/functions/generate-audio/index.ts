import { encodeBase64 } from 'jsr:@std/encoding@1/base64'

import { type AudioPace, audioPaces } from '../_shared/contracts/database.ts'

import { ElevenLabsSpeechError, generateElevenLabsSpeech } from '../_shared/providers/elevenlabs.ts'
import { measureAsync } from '../_shared/utils/measure-async.ts'

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

	if (!isAudioInput(body)) {
		return jsonError('invalid_input', 400)
	}

	try {
		const { result, durationMs } = await measureAsync(() =>
			generateElevenLabsSpeech({
				text: body.text.trim(),
				voiceName: body.voiceName,
				languageCode: body.languageCode,
				stylePreset: body.stylePreset,
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
					type: 'audio',
					// Metadata only; the provider's voice settings are unchanged.
					pace: body.pace ?? 'normal',
					// Request latency, not audio length.
					durationMs,
					requestId: result.requestId ?? null,
					model: result.modelId,
				},
			},
			{ headers: corsHeaders },
		)
	} catch (error) {
		console.error('[generate-audio]', error)
		if (error instanceof ElevenLabsSpeechError) {
			if (error.code === 'missing_api_key') {
				return jsonError('server_misconfigured', 500)
			}
			if (error.code === 'unknown_voice') {
				return jsonError('unknown_voice', 400)
			}
			if (error.code === 'unknown_style_preset') {
				return jsonError('unknown_style_preset', 400)
			}
		}
		return jsonError('audio_failed', 502)
	}
})

function isAudioInput(value: unknown): value is {
	text: string
	voiceName: string
	languageCode: string
	stylePreset?: string
	pace?: AudioPace
} {
	if (!value || typeof value !== 'object') {
		return false
	}

	const input = value as Record<string, unknown>
	return (
		typeof input.text === 'string' &&
		input.text.trim().length > 0 &&
		input.text.length <= 5_000 &&
		typeof input.voiceName === 'string' &&
		input.voiceName.length > 0 &&
		typeof input.languageCode === 'string' &&
		input.languageCode.length >= 2 &&
		input.languageCode.length <= 16 &&
		(input.stylePreset === undefined || typeof input.stylePreset === 'string') &&
		(input.pace === undefined || audioPaces.some((pace) => pace === input.pace))
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
