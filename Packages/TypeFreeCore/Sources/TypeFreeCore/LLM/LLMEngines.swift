import Foundation

/// 聊天消息。
public struct ChatMessage: Codable, Sendable {
    public let role: String // "system" | "user" | "assistant"
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// 二阶段 LLM 引擎协议。支持 SSE 流式与一次性返回两种消费方式。
public protocol LLMEngine: Sendable {
    /// 流式生成：逐段产出增量文本。
    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}

public enum LLMFactory {
    public static func make(
        provider: ProviderKind,
        model: String,
        credentials: ProviderCredentials,
        thinking: ThinkingMode = .off,
        temperature: Double = 0.6
    ) throws -> LLMEngine {
        if provider == .gemini {
            let resolver = EndpointResolver(kind: .gemini, role: .llm, credentials: credentials)
            return GeminiLLMEngine(resolver: resolver, client: HTTPClient(), model: model)
        }
        let resolver = EndpointResolver(kind: provider, role: .llm, credentials: credentials)
        return OpenAICompatLLMEngine(
            resolver: resolver,
            client: HTTPClient(),
            model: model,
            thinking: thinking,
            temperature: temperature
        )
    }
}

// MARK: - OpenAI 兼容

/// OpenAI 兼容 chat/completions：DeepSeek / 豆包方舟 / 百炼兼容模式 / 硅基 / Groq / Ollama / 自定义网关。
public struct OpenAICompatLLMEngine: LLMEngine {
    let resolver: EndpointResolver
    let client: HTTPClient
    let model: String
    let thinking: ThinkingMode
    let temperature: Double

    struct RequestBody: Encodable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
        let temperature: Double
        let thinking: ThinkingParam?
    }

    /// DeepSeek 新版思考控制参数（对齐上游 `{"thinking": {"type": "enabled"}}` 注入）。
    struct ThinkingParam: Encodable {
        let type: String
    }

    struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message?
            let delta: Message?
        }
        let choices: [Choice]?
    }

    public func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = try resolver.chatCompletionsURL()
                    var headers = try resolver.authHeaders()
                    headers["Content-Type"] = "application/json"

                    let body = RequestBody(
                        model: model,
                        messages: messages,
                        stream: true,
                        temperature: temperature,
                        thinking: thinkingBody()
                    )
                    let bodyData = try JSONEncoder().encode(body)

                    var parser = SSEParser()
                    for try await chunk in client.streamBytes(url: url, headers: headers, body: bodyData) {
                        guard let text = String(data: chunk, encoding: .utf8) else { continue }
                        for event in parser.feed(text) {
                            guard event != "[DONE]" else { continue }
                            guard let jsonData = event.data(using: .utf8),
                                  let decoded = try? JSONDecoder().decode(ResponseBody.self, from: jsonData),
                                  let delta = decoded.choices?.first?.delta?.content ?? decoded.choices?.first?.message?.content,
                                  !delta.isEmpty else { continue }
                            continuation.yield(delta)
                        }
                    }
                    for event in parser.flush() {
                        guard event != "[DONE]" else { continue }
                        guard let jsonData = event.data(using: .utf8),
                              let decoded = try? JSONDecoder().decode(ResponseBody.self, from: jsonData),
                              let delta = decoded.choices?.first?.delta?.content ?? decoded.choices?.first?.message?.content,
                              !delta.isEmpty else { continue }
                        continuation.yield(delta)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func thinkingBody() -> ThinkingParam? {
        // 仅对 DeepSeek 注入 thinking 控制参数（对齐上游），
        // 其他 OpenAI 兼容网关对未知字段可能报 400，默认不带。
        guard thinking == .on, resolver.kind == .deepseek else { return nil }
        return ThinkingParam(type: "enabled")
    }
}

// MARK: - Gemini

/// Gemini REST `streamGenerateContent?alt=sse`。
public struct GeminiLLMEngine: LLMEngine {
    let resolver: EndpointResolver
    let client: HTTPClient
    let model: String

    struct RequestBody: Encodable {
        struct Content: Encodable {
            struct Part: Encodable { let text: String }
            let role: String
            let parts: [Part]
        }
        let contents: [Content]
        let systemInstruction: Content?
        let generationConfig: GenerationConfig?
    }

    struct GenerationConfig: Encodable {
        let temperature: Double
    }

    struct ResponseBody: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    public func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let system = messages.filter { $0.role == "system" }.map(\.content).joined(separator: "\n\n")
                    let contents = messages.filter { $0.role != "system" }.map { message in
                        RequestBody.Content(
                            role: message.role == "assistant" ? "model" : "user",
                            parts: [.init(text: message.content)]
                        )
                    }
                    let body = RequestBody(
                        contents: contents,
                        systemInstruction: system.isEmpty ? nil : .init(role: "user", parts: [.init(text: system)]),
                        generationConfig: .init(temperature: 0.6)
                    )

                    let url = try resolver.geminiStreamURL(model: model)
                    let headers = try resolver.authHeaders()
                    let bodyData = try JSONEncoder().encode(body)

                    var parser = SSEParser()
                    for try await chunk in client.streamBytes(url: url, headers: headers, body: bodyData) {
                        guard let text = String(data: chunk, encoding: .utf8) else { continue }
                        for event in parser.feed(text) {
                            guard let jsonData = event.data(using: .utf8),
                                  let decoded = try? JSONDecoder().decode(ResponseBody.self, from: jsonData),
                                  let delta = decoded.candidates?.first?.content?.parts?
                                      .compactMap(\.text)
                                      .joined(),
                                  !delta.isEmpty else { continue }
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
