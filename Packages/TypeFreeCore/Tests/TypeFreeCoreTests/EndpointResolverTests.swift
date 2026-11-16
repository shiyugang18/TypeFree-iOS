import XCTest
@testable import TypeFreeCore

final class EndpointResolverTests: XCTestCase {

    func testDeepSeekASRUsesStrictEndpoint() throws {
        let resolver = EndpointResolver(kind: .deepseek, role: .stt, credentials: ProviderCredentials(apiKey: "sk-test"))
        let url = try resolver.sttTranscriptionURL()
        XCTAssertEqual(url.absoluteString, "https://api.deepseek.com/v1/tools/asr")
        XCTAssertTrue(resolver.usesStrictFileOnlyASR)
    }

    func testSiliconFlowTranscriptionURL() throws {
        let resolver = EndpointResolver(kind: .siliconflow, role: .stt, credentials: ProviderCredentials(apiKey: "sk-x"))
        let url = try resolver.sttTranscriptionURL()
        XCTAssertEqual(url.absoluteString, "https://api.siliconflow.cn/v1/audio/transcriptions")
        XCTAssertFalse(resolver.usesStrictFileOnlyASR)
    }

    func testCustomBaseURLOverride() throws {
        let resolver = EndpointResolver(
            kind: .custom,
            role: .stt,
            credentials: ProviderCredentials(apiKey: "k", baseURL: "http://192.168.1.5:8080/v1/")
        )
        let url = try resolver.sttTranscriptionURL()
        XCTAssertEqual(url.absoluteString, "http://192.168.1.5:8080/v1/audio/transcriptions")
    }

    func testChatCompletionsURLs() throws {
        let deepseek = EndpointResolver(kind: .deepseek, role: .llm, credentials: ProviderCredentials(apiKey: "k"))
        XCTAssertEqual(try deepseek.chatCompletionsURL().absoluteString, "https://api.deepseek.com/v1/chat/completions")

        let bailian = EndpointResolver(kind: .bailian, role: .llm, credentials: ProviderCredentials(apiKey: "k"))
        XCTAssertEqual(try bailian.chatCompletionsURL().absoluteString,
                       "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")

        let ark = EndpointResolver(kind: .volcengine, role: .llm, credentials: ProviderCredentials(arkAPIKey: "k"))
        XCTAssertEqual(try ark.chatCompletionsURL().absoluteString,
                       "https://ark.cn-beijing.volces.com/api/v3/chat/completions")
    }

    func testGeminiStreamURL() throws {
        let resolver = EndpointResolver(kind: .gemini, role: .llm, credentials: ProviderCredentials(apiKey: "g"))
        let url = try resolver.geminiStreamURL(model: "gemini-2.0-flash")
        XCTAssertEqual(url.absoluteString,
                       "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent?alt=sse")
        let headers = try resolver.authHeaders()
        XCTAssertEqual(headers["x-goog-api-key"], "g")
    }

    func testMissingKeyThrows() {
        let resolver = EndpointResolver(kind: .deepseek, role: .llm, credentials: ProviderCredentials())
        XCTAssertThrowsError(try resolver.authHeaders()) { error in
            XCTAssertTrue("\(error)".contains("DeepSeek"))
        }
    }

    func testVolcengineUsesArkKey() throws {
        let resolver = EndpointResolver(
            kind: .volcengine,
            role: .llm,
            credentials: ProviderCredentials(arkAPIKey: "ark-key", asrAccessToken: "voice-token")
        )
        let headers = try resolver.authHeaders()
        XCTAssertEqual(headers["Authorization"], "Bearer ark-key")
    }
}
