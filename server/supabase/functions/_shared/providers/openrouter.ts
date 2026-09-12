const baseUrl = 'https://openrouter.ai/api/v1'
const requestTimeoutMs = 120_000

type OpenRouterImageResponse = {
	data?: Array<{
		b64_json?: string
		media_type?: string
	}>
}

type OpenRouterTextResponse = {
	choices?: Array<{
		message?: {
			content?: string | null
		}
	}>
}

export class OpenRouterImageError extends Error {
	constructor(
		public readonly code: 'missing_api_key' | 'request_failed' | 'no_image',
		message?: string,
	) {
		super(message ?? code)
		this.name = 'OpenRouterImageError'
	}
}

export class OpenRouterTextError extends Error {
	constructor(
		public readonly code:
			| 'missing_api_key'
			| 'request_failed'
			| 'no_content'
			| 'invalid_json',
		message?: string,
	) {
		super(message ?? code)
		this.name = 'OpenRouterTextError'
	}
}

export async function generateOpenRouterStructuredText({
	model,
	schemaName,
	jsonSchema,
	systemPrompt,
	userPrompt,
}: {
	model: string
	schemaName: string
	jsonSchema: Record<string, unknown>
	systemPrompt: string | null
	userPrompt: string
}): Promise<unknown> {
	const apiKey = Deno.env.get('OPENROUTER_API_KEY')
	if (!apiKey) {
		throw new OpenRouterTextError('missing_api_key')
	}

	const response = await fetch(`${baseUrl}/chat/completions`, {
		method: 'POST',
		headers: {
			Authorization: `Bearer ${apiKey}`,
			'Content-Type': 'application/json',
		},
		body: JSON.stringify({
			model,
			messages: [
				...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
				{ role: 'user', content: userPrompt },
			],
			response_format: {
				type: 'json_schema',
				json_schema: {
					name: schemaName,
					strict: true,
					schema: jsonSchema,
				},
			},
			provider: { require_parameters: true },
		}),
		signal: AbortSignal.timeout(requestTimeoutMs),
	}).catch((error: unknown) => {
		const message = error instanceof Error ? error.message : String(error)
		throw new OpenRouterTextError('request_failed', message)
	})

	if (!response.ok) {
		throw new OpenRouterTextError(
			'request_failed',
			`OpenRouter returned HTTP ${response.status}`,
		)
	}

	let payload: OpenRouterTextResponse
	try {
		payload = (await response.json()) as OpenRouterTextResponse
	} catch {
		throw new OpenRouterTextError('request_failed', 'OpenRouter returned invalid JSON')
	}

	const content = payload.choices?.[0]?.message?.content
	if (!content) {
		throw new OpenRouterTextError('no_content')
	}

	try {
		return JSON.parse(content) as unknown
	} catch {
		throw new OpenRouterTextError('invalid_json')
	}
}

export async function generateOpenRouterImage({
	model,
	prompt,
	referenceImages = [],
	imageSize = '1K',
	aspectRatio = '4:3',
}: {
	model: string
	prompt: string
	referenceImages?: Array<{ base64: string; mimeType: string }>
	imageSize?: '1K' | '2K' | '4K'
	aspectRatio?: string
}): Promise<{ bytes: Uint8Array; contentType: string }> {
	const apiKey = Deno.env.get('OPENROUTER_API_KEY')
	if (!apiKey) {
		throw new OpenRouterImageError('missing_api_key')
	}

	const response = await fetch(`${baseUrl}/images`, {
		method: 'POST',
		headers: {
			Authorization: `Bearer ${apiKey}`,
			'Content-Type': 'application/json',
		},
		body: JSON.stringify({
			model,
			prompt,
			resolution: imageSize,
			aspect_ratio: aspectRatio,
			// Reference images are supported now so future style-consistent generation
			// will not require changing this provider API. The current endpoint does not send any.
			...(referenceImages.length > 0
				? {
					input_references: referenceImages.map(({ base64, mimeType }) => ({
						type: 'image_url',
						image_url: { url: `data:${mimeType};base64,${base64}` },
					})),
				}
				: {}),
		}),
		signal: AbortSignal.timeout(requestTimeoutMs),
	}).catch((error: unknown) => {
		const message = error instanceof Error ? error.message : String(error)
		throw new OpenRouterImageError('request_failed', message)
	})

	if (!response.ok) {
		throw new OpenRouterImageError(
			'request_failed',
			`OpenRouter returned HTTP ${response.status}`,
		)
	}

	let payload: OpenRouterImageResponse
	try {
		payload = (await response.json()) as OpenRouterImageResponse
	} catch {
		throw new OpenRouterImageError('request_failed', 'OpenRouter returned invalid JSON')
	}

	const image = payload.data?.[0]
	if (!image?.b64_json) {
		throw new OpenRouterImageError('no_image')
	}

	let bytes: Uint8Array
	try {
		const binary = atob(image.b64_json)
		bytes = new Uint8Array(binary.length)
		for (let index = 0; index < binary.length; index += 1) {
			bytes[index] = binary.charCodeAt(index)
		}
	} catch {
		throw new OpenRouterImageError('request_failed', 'OpenRouter returned invalid image data')
	}

	const contentType = image.media_type?.startsWith('image/') ? image.media_type : 'image/png'

	return { bytes, contentType }
}
