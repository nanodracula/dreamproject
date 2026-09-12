export async function measureAsync<T>(
	operation: () => Promise<T>,
): Promise<{ result: T; durationMs: number }> {
	const startedAt = performance.now()
	const result = await operation()

	return {
		result,
		durationMs: Math.round(performance.now() - startedAt),
	}
}
