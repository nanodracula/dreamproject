const baseUrl = 'https://api.elevenlabs.io'
const defaultModelId = 'eleven_v3'
const outputFormat = 'mp3_44100_128'
const requestTimeoutMs = 60_000

/**
 * Best practices for ElevenLabs voices:
 * - https://elevenlabs.io/docs/overview/capabilities/text-to-speech/best-practices
 */
type ElevenLabsVoice = {
	/** ElevenLabs voice_id used in the TTS URL. */
	id: string
	/** Display name in the ElevenLabs library. */
	name: string
	/** ISO 639-1 code this voice is tuned for. */
	language: string
	gender: 'female' | 'male' | 'neutral'
	/** Model this voice sounds best on. */
	modelId: 'eleven_v3' | 'eleven_multilingual_v2' | 'eleven_flash_v2_5' | 'eleven_turbo_v2_5'
	/** Tone, age, where it fits. */
	description: string
	/** Library page, for humans only. */
	url?: string
	/** Applied to text before sending; key of stylePresets. */
	stylePreset?: string
	/** Sent as voice_settings; omit to use the voice's defaults. */
	voiceSettings?: {
		stability?: number
		similarityBoost?: number
		style?: number
		useSpeakerBoost?: boolean
		speed?: number
	}
}

const voiceMap = {
	japaneseFemaleMalo: {
		id: 'tPngN48DaHQOvU1YFqtz',
		name: 'Malo',
		language: 'ja',
		gender: 'female',
		modelId: 'eleven_v3',
		description:
			'Friendly, clear and natural. Soft and gentle tone, soothing, like a close friend speaking directly to you. Default for Japanese.',
		url: 'https://elevenlabs.io/voices/tPngN48DaHQOvU1YFqtz',
	},
	japaneseGirlSuzu: {
		id: '6awt6FKyZGV0HyQEwisX',
		name: 'Suzu',
		language: 'ja',
		gender: 'female',
		modelId: 'eleven_v3',
		description: 'Young, bright girl voice.',
		url: 'https://elevenlabs.io/voices/6awt6FKyZGV0HyQEwisX',
	},
	japaneseFemaleFumi: {
		id: 'R6qgCCGI7RWKXCagm158',
		name: 'Fumi',
		language: 'ja',
		gender: 'female',
		modelId: 'eleven_v3',
		description: 'Adult, calm, neutral register.',
		url: 'https://elevenlabs.io/voices/R6qgCCGI7RWKXCagm158',
	},
	koreanFemaleRosa: {
		id: 'sf8Bpb1IU97NI9BHSMRf',
		name: 'Rosa',
		language: 'ko',
		gender: 'female',
		modelId: 'eleven_v3',
		description: 'Warm, mid-paced, clear consonants.',
		url: 'https://elevenlabs.io/voices/sf8Bpb1IU97NI9BHSMRf',
	},
} satisfies Record<string, ElevenLabsVoice>

export type VoiceName = keyof typeof voiceMap

const stylePresets: Record<string, (text: string) => string> = {
	samurai: (text) => `[excitedly] ${text}`,
}

export class ElevenLabsSpeechError extends Error {
	constructor(
		public readonly code:
			| 'missing_api_key'
			| 'unknown_voice'
			| 'unknown_style_preset'
			| 'request_failed',
		message?: string,
	) {
		super(message ?? code)
		this.name = 'ElevenLabsSpeechError'
	}
}

export async function generateElevenLabsSpeech({
	text,
	voiceName,
	languageCode,
	stylePreset,
	modelId,
}: {
	text: string
	voiceName: string
	languageCode: string
	stylePreset?: string
	modelId?: string
}): Promise<{
	bytes: Uint8Array
	contentType: string
	requestId: string | null
	modelId: string
}> {
	const apiKey = Deno.env.get('ELEVENLABS_API_KEY')
	if (!apiKey) {
		throw new ElevenLabsSpeechError('missing_api_key')
	}

	const voice: ElevenLabsVoice | undefined = voiceMap[voiceName as VoiceName]
	if (!voice) {
		throw new ElevenLabsSpeechError('unknown_voice')
	}
	const resolvedModelId = modelId ?? voice.modelId ?? defaultModelId

	let processedText = text
	const presetName = stylePreset ?? voice.stylePreset
	if (presetName) {
		const preset = stylePresets[presetName]
		if (!preset) {
			throw new ElevenLabsSpeechError('unknown_style_preset')
		}
		processedText = preset(text)
	}

	const voiceSettings = voice.voiceSettings && {
		stability: voice.voiceSettings.stability,
		similarity_boost: voice.voiceSettings.similarityBoost,
		style: voice.voiceSettings.style,
		use_speaker_boost: voice.voiceSettings.useSpeakerBoost,
		speed: voice.voiceSettings.speed,
	}

	const url = new URL(`/v1/text-to-speech/${encodeURIComponent(voice.id)}`, baseUrl)
	url.searchParams.set('output_format', outputFormat)

	const response = await fetch(url, {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			'xi-api-key': apiKey,
		},
		body: JSON.stringify({
			text: processedText,
			model_id: resolvedModelId,
			language_code: languageCode,
			voice_settings: voiceSettings,
			// apply_language_text_normalization is rejected by eleven_v3.
		}),
		signal: AbortSignal.timeout(requestTimeoutMs),
	}).catch((error: unknown) => {
		const message = error instanceof Error ? error.message : String(error)
		throw new ElevenLabsSpeechError('request_failed', message)
	})

	if (!response.ok) {
		throw new ElevenLabsSpeechError(
			'request_failed',
			`ElevenLabs returned HTTP ${response.status}`,
		)
	}

	const bytes = new Uint8Array(await response.arrayBuffer())
	if (bytes.length === 0) {
		throw new ElevenLabsSpeechError('request_failed', 'ElevenLabs returned empty audio')
	}

	return {
		bytes,
		contentType: response.headers.get('content-type') ?? 'audio/mpeg',
		requestId: response.headers.get('request-id'),
		modelId: resolvedModelId,
	}
}
