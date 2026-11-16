import Foundation

/// 端点解析器：根据服务商 + 角色解析请求 URL。
/// 对齐上游 `EndpointResolver` 的语义，包括 DeepSeek 专用 `/v1/tools/asr` 识别。
public struct EndpointResolver: Sendable {

    public enum EndpointError: Error, LocalizedError {
        case missingBaseURL(ProviderKind)
        case missingCredentials(ProviderKind)

        public var errorDescription: String? {
            switch self {
            case .missingBaseURL(let kind):
                return "\(kind.displayName) 尚未配置 Base URL"
            case .missingCredentials(let kind):
                return "\(kind.displayName) 尚未配置 API Key，请先在「API 配置」页填写"
            }
        }
    }

    public let kind: ProviderKind
    public let role: AIRole
    public let credentials: ProviderCredentials

    public init(kind: ProviderKind, role: AIRole, credentials: ProviderCredentials) {
        self.kind = kind
        self.role = role
        self.credentials = credentials
    }

    /// 鉴权 HTTP 头。
    public func authHeaders() throws -> [String: String] {
        switch kind {
        case .gemini:
            guard !credentials.apiKey.isEmpty else { throw EndpointError.missingCredentials(.gemini) }
            return ["x-goog-api-key": credentials.apiKey]
        case .ollama:
            return [:]
        case .volcengine:
            let key = credentials.arkAPIKey
            guard !key.isEmpty else { throw EndpointError.missingCredentials(.volcengine) }
            return ["Authorization": "Bearer \(key)"]
        case .custom:
            var headers: [String: String] = [:]
            if !credentials.apiKey.isEmpty {
                headers["Authorization"] = "Bearer \(credentials.apiKey)"
            }
            return headers
        default:
            let key = credentials.apiKey
            guard !key.isEmpty else { throw EndpointError.missingCredentials(kind) }
            return ["Authorization": "Bearer \(key)"]
        }
    }

    /// OpenAI 兼容 chat/completions 完整 URL。
    public func chatCompletionsURL() throws -> URL {
        switch kind {
        case .gemini:
            // Gemini 走独立协议，不提供 chat/completions。
            throw EndpointError.missingBaseURL(.gemini)
        default:
            let base = try effectiveBaseURL()
            let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
            return URL(string: "\(trimmed)/chat/completions")!
        }
    }

    /// 一阶段听写（REST 整包）URL。
    public func sttTranscriptionURL() throws -> URL {
        switch kind {
        case .deepseek:
            // DeepSeek 官方语音识别，严格协议：POST /v1/tools/asr，仅传 file 字段。
            return URL(string: "https://api.deepseek.com/v1/tools/asr")!
        case .ollama:
            throw EndpointError.missingBaseURL(.ollama)
        default:
            let base = try effectiveBaseURL()
            let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
            return URL(string: "\(trimmed)/audio/transcriptions")!
        }
    }

    /// DeepSeek ASR 专用端点判定（自定义网关若包含 /tools/asr 也走 file-only 严格模式）。
    public var usesStrictFileOnlyASR: Bool {
        if case .deepseek = kind { return true }
        return false
    }

    /// Gemini streamGenerateContent URL。
    public func geminiStreamURL(model: String) throws -> URL {
        guard kind == .gemini else { throw EndpointError.missingBaseURL(.gemini) }
        let base = try effectiveBaseURL()
        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        return URL(string: "\(trimmed)/models/\(model):streamGenerateContent?alt=sse")!
    }

    func effectiveBaseURL() throws -> String {
        let custom = credentials.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        let def = ProviderDefaults.baseURL(for: kind)
        guard !def.isEmpty else { throw EndpointError.missingBaseURL(kind) }
        return def
    }
}
