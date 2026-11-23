import Foundation

/// 服务商种类。与上游 TypeFree Android 版的「服务商凭证保险箱」对齐。
public enum ProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case deepseek
    case siliconflow      // 硅基流动
    case bailian          // 阿里云百炼（通义千问 / DashScope）
    case volcengine       // 火山引擎（豆包：方舟 LLM + 语音 SeedASR）
    case zhipu            // 智谱（GLM 系列大模型 + GLM-ASR 语音识别）
    case gemini
    case groq
    case ollama
    case custom           // 自定义 OpenAI 兼容网关

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .siliconflow: return "硅基流动"
        case .bailian: return "阿里云百炼"
        case .volcengine: return "火山引擎豆包"
        case .zhipu: return "智谱 GLM"
        case .gemini: return "Google Gemini"
        case .groq: return "Groq"
        case .ollama: return "本地 Ollama"
        case .custom: return "自定义网关"
        }
    }

    /// 每个凭证槽需要填写哪些字段。
    public var credentialFields: [CredentialField] {
        switch self {
        case .deepseek, .siliconflow, .bailian, .zhipu, .groq:
            return [.apiKey]
        case .volcengine:
            // 方舟（文本大模型）与豆包语音是两个独立入口，分开填写。
            return [.arkAPIKey, .asrAccessToken, .asrAppID]
        case .gemini:
            return [.apiKey]
        case .ollama:
            return [.baseURL]
        case .custom:
            return [.baseURL, .apiKey]
        }
    }
}

/// 凭证字段种类。
public enum CredentialField: String, Codable, CaseIterable, Sendable {
    case apiKey
    case arkAPIKey      // 火山方舟 Key（豆包 LLM）
    case asrAccessToken // 火山语音 Access Token / 新版 X-Api-Key
    case asrAppID       // 火山语音 AppID
    case baseURL

    public var displayName: String {
        switch self {
        case .apiKey: return "API Key"
        case .arkAPIKey: return "方舟 API Key（豆包 LLM）"
        case .asrAccessToken: return "语音 Access Token"
        case .asrAppID: return "语音 AppID"
        case .baseURL: return "Base URL"
        }
    }
}

/// 单个服务商的凭证。
public struct ProviderCredentials: Codable, Equatable, Sendable {
    public var apiKey: String
    public var arkAPIKey: String
    public var asrAccessToken: String
    public var asrAppID: String
    public var baseURL: String

    public init(
        apiKey: String = "",
        arkAPIKey: String = "",
        asrAccessToken: String = "",
        asrAppID: String = "",
        baseURL: String = ""
    ) {
        self.apiKey = apiKey
        self.arkAPIKey = arkAPIKey
        self.asrAccessToken = asrAccessToken
        self.asrAppID = asrAppID
        self.baseURL = baseURL
    }

    public var isEmpty: Bool {
        apiKey.isEmpty && arkAPIKey.isEmpty && asrAccessToken.isEmpty && asrAppID.isEmpty && baseURL.isEmpty
    }
}

/// AI 工作流中的角色。
public enum AIRole: String, Codable, Sendable {
    case stt   // 一阶段：听音转写
    case llm   // 二阶段：润色 / 帮写 / 快译
}

/// 工作流路由配置：一阶段听音 + 二阶段大脑可以来自不同服务商（BYOK 混搭）。
public struct WorkflowConfig: Codable, Equatable, Sendable {
    public var sttProvider: ProviderKind
    public var sttModel: String
    public var llmProvider: ProviderKind
    public var llmModel: String
    /// 思考模式：日常润色建议关。
    public var llmThinking: ThinkingMode
    /// 是否启用二阶段润色（关闭则识别直出，最快）。
    public var polishEnabled: Bool

    public init(
        sttProvider: ProviderKind = .siliconflow,
        sttModel: String = ProviderDefaults.sttModel(for: .siliconflow),
        llmProvider: ProviderKind = .deepseek,
        llmModel: String = ProviderDefaults.llmModel(for: .deepseek),
        llmThinking: ThinkingMode = .off,
        polishEnabled: Bool = true
    ) {
        self.sttProvider = sttProvider
        self.sttModel = sttModel
        self.llmProvider = llmProvider
        self.llmModel = llmModel
        self.llmThinking = llmThinking
        self.polishEnabled = polishEnabled
    }
}

public enum ThinkingMode: String, Codable, CaseIterable, Sendable {
    case off = "关闭思考（极速）"
    case auto = "自动 (AUTO)"
    case on = "开启思考"

    public var rawEnabled: Bool {
        switch self {
        case .off: return false
        case .on: return true
        case .auto: return false
        }
    }
}

/// 各服务商的官方默认端点与推荐模型（对齐上游 docs/domestic-api-setup-guide.md）。
public enum ProviderDefaults {
    public static func baseURL(for kind: ProviderKind) -> String {
        switch kind {
        case .deepseek: return "https://api.deepseek.com/v1"
        case .siliconflow: return "https://api.siliconflow.cn/v1"
        case .bailian: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .volcengine: return "https://ark.cn-beijing.volces.com/api/v3"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .groq: return "https://api.groq.com/openai/v1"
        case .ollama: return "http://127.0.0.1:11434/v1"
        case .custom: return ""
        }
    }

    /// 一阶段听音推荐模型。
    public static func sttModel(for kind: ProviderKind) -> String {
        switch kind {
        case .deepseek: return "" // DeepSeek 走专用 /v1/tools/asr，无模型字段
        case .siliconflow: return "FunAudioLLM/SenseVoiceSmall"
        case .bailian: return "paraformer-realtime-v2"
        case .volcengine: return "bigmodel" // SeedASR 2.0
        case .zhipu: return "glm-asr-2512"
        case .gemini: return "gemini-2.0-flash"
        case .groq: return "whisper-large-v3"
        case .ollama: return ""
        case .custom: return ""
        }
    }

    /// 二阶段润色推荐模型。
    public static func llmModel(for kind: ProviderKind) -> String {
        switch kind {
        case .deepseek: return "deepseek-chat"
        case .siliconflow: return "Qwen/Qwen2.5-7B-Instruct"
        case .bailian: return "qwen-turbo-latest"
        case .volcengine: return "doubao-seed-2-1-lite-260915"
        case .zhipu: return "glm-4.6"
        case .gemini: return "gemini-2.0-flash"
        case .groq: return "llama-3.3-70b-versatile"
        case .ollama: return "qwen2.5:7b"
        case .custom: return ""
        }
    }

    /// 该服务商是否支持 REST 整包听写（iOS v0.1 支持的形态）。
    public static func supportsRESTSTT(_ kind: ProviderKind) -> Bool {
        switch kind {
        case .deepseek, .siliconflow, .zhipu, .groq, .custom:
            return true
        default:
            // gemini 亦可用 audio 直出，v0.1 先不启用；bailian/volcengine 为 WSS 流式，Phase 2。
            return false
        }
    }
}
