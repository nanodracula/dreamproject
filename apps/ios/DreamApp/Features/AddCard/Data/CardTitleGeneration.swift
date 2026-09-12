import Foundation
import Supabase

/// Payloads of the `generate-text` function's `card-title` workflow and the
/// client that invokes it. The wire format is owned by
/// `server/supabase/functions/generate-text/workflows/card-title.ts`; change
/// both sides together.
nonisolated struct CardTitleInput: Encodable, Equatable, Sendable {
    var inputText: String
    /// A `LearningLanguage.code` the server accepts.
    var learningLanguageCode: String
    /// English name of the translation language, e.g. "English".
    var nativeLanguage: String
    /// Language and script description for the prompt, e.g. "Japanese (Kanji and kana)".
    var nativeWritingSystem: String
    /// A `KnowledgeLevel` raw value.
    var userKnowledgeLevel: String
}

nonisolated extension CardTitleInput {
    /// Builds the request from the app's language configuration.
    init(
        inputText: String,
        learningLanguage: LearningLanguage,
        nativeLanguage: NativeLanguage,
        knowledgeLevel: KnowledgeLevel
    ) {
        self.init(
            inputText: inputText,
            learningLanguageCode: learningLanguage.code,
            nativeLanguage: nativeLanguage.name,
            nativeWritingSystem: "\(learningLanguage.promptName) (\(learningLanguage.writing.standard))",
            userKnowledgeLevel: knowledgeLevel.rawValue
        )
    }
}

nonisolated enum CardTitleTone: String, Decodable, Sendable, CaseIterable {
    case formal
    case polite
    case casual
    case slang
}

nonisolated enum CardTitleContentType: String, Decodable, Sendable, CaseIterable {
    case word
    case sentence
}

/// One suggested title. `sentenceType` is `nil` for words.
nonisolated struct CardTitleVariant: Decodable, Equatable, Sendable {
    var title: String
    var translation: String
    var contentType: CardTitleContentType
    var sentenceType: SentenceType?
    var tone: CardTitleTone
    var recommended: Bool
    var info: Info

    nonisolated struct Info: Decodable, Equatable, Sendable {
        var desc: String
    }
}

/// Why title generation failed. Raw values are the server's wire codes and
/// the keys of the alert messages recorded in `docs/design.md`.
nonisolated enum CardTitleGenerationError: String, Error, Equatable, Sendable {
    case invalidRequest = "invalid_request"
    case serverMisconfigured = "server_misconfigured"
    case invalidModelOutput = "invalid_model_output"
    case providerFailed = "provider_failed"
    case invalidResponse = "invalid_response"
    case unauthorized
    case notFound = "not_found"
    case rateLimited = "rate_limited"
    case timeout
    case serverFailed = "server_failed"
    case networkFailed = "network_failed"
}

/// Feature contract, so screens and previews can substitute the network.
nonisolated protocol CardTitleGenerating: Sendable {
    func generateTitles(for input: CardTitleInput) async throws(CardTitleGenerationError) -> [CardTitleVariant]
}

/// Invokes the function through the shared client. No session is required:
/// the client sends the anon key when there is none, and the router accepts it.
nonisolated struct CardTitleGeneration: CardTitleGenerating {
    private let supabase: SupabaseClient

    /// Generation can exceed URLSession's 60-second default.
    private static let timeout: TimeInterval = 120

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func generateTitles(for input: CardTitleInput) async throws(CardTitleGenerationError) -> [CardTitleVariant] {
        let response: Response
        do {
            response = try await supabase.functions.invoke(
                "generate-text",
                options: FunctionInvokeOptions(body: Request(input: input), timeoutInterval: Self.timeout),
                decoder: JSONDecoder()
            )
        } catch FunctionsError.httpError(let status, let body) {
            throw Self.error(status: status, body: body)
        } catch FunctionsError.relayError {
            throw .serverFailed
        } catch is DecodingError {
            throw .invalidResponse
        } catch let error as URLError where error.code == .timedOut {
            throw .timeout
        } catch {
            throw .networkFailed
        }
        return response.data.titleVariants
    }

    /// Prefers the server's `{ "code": … }` body; falls back to the status.
    private static func error(status: Int, body: Data) -> CardTitleGenerationError {
        if let error = try? JSONDecoder().decode(ErrorBody.self, from: body),
           let known = CardTitleGenerationError(rawValue: error.code) {
            return known
        }
        return switch status {
        case 401, 403: .unauthorized
        case 404: .notFound
        case 408, 504: .timeout
        case 429: .rateLimited
        case 500...: .serverFailed
        default: .invalidResponse
        }
    }

    private nonisolated struct Request: Encodable {
        let type = "card-title"
        let input: CardTitleInput
    }

    private nonisolated struct Response: Decodable {
        let data: Output

        nonisolated struct Output: Decodable {
            let titleVariants: [CardTitleVariant]
        }
    }

    private nonisolated struct ErrorBody: Decodable {
        let code: String
    }
}
