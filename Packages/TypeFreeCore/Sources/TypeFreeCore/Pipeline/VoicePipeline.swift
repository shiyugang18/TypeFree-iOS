import Foundation

/// 语音管线编排：录音数据 → 一阶段转写 → （可选）二阶段润色 → 最终文本。
/// 主 App 听写试场与键盘扩展共用此管线。
public struct VoicePipeline: Sendable {

    public enum Phase: String, Sendable {
        case idle
        case transcribing   // 一阶段听音
        case polishing      // 二阶段润色
        case done
    }

    public struct Outcome: Sendable {
        public let rawText: String
        public let finalText: String
        public let usedPolish: Bool
        public let providerSummary: String
    }

    public typealias PhaseHandler = @Sendable (Phase) -> Void

    let settings: TypeFreeSettings
    let vault: ProviderVault
    let hostHint: String?

    public init(settings: TypeFreeSettings, vault: ProviderVault, hostHint: String? = nil) {
        self.settings = settings
        self.vault = vault
        self.hostHint = hostHint
    }

    /// 执行完整管线。
    /// - Parameter onRawText: 一阶段转写完成时回调原始文本（用于键盘先插草稿，润色完再替换）。
    public func run(
        wavData: Data,
        intent: PolishService.Intent = .dictate,
        attitude: AttitudeChip? = nil,
        onPhase: PhaseHandler? = nil,
        onRawText: ((String) -> Void)? = nil
    ) async throws -> Outcome {
        let workflow = settings.workflow

        // 一阶段：听音转写
        onPhase?(.transcribing)
        let sttCredentials = vault.credentials(for: workflow.sttProvider)
        guard !sttCredentials.isEmpty else {
            throw PipelineError.sttNotConfigured(workflow.sttProvider)
        }
        guard ProviderDefaults.supportsRESTSTT(workflow.sttProvider) else {
            throw PipelineError.sttUnsupported(workflow.sttProvider)
        }
        let sttEngine = try STTFactory.make(
            provider: workflow.sttProvider,
            model: workflow.sttModel,
            credentials: sttCredentials
        )
        let rawText = try await sttEngine.transcribe(wavData: wavData)
        onRawText?(rawText)

        // 二阶段：润色
        var finalText = rawText
        let usedPolish = workflow.polishEnabled
        if usedPolish {
            onPhase?(.polishing)
            let llmCredentials = vault.credentials(for: workflow.llmProvider)
            guard !llmCredentials.isEmpty else {
                // LLM 未配置则回退为直出，不报错（对齐上游：听音可用即可先出字）。
                onPhase?(.done)
                return Outcome(
                    rawText: rawText,
                    finalText: rawText,
                    usedPolish: false,
                    providerSummary: workflow.sttProvider.displayName
                )
            }
            let engine = try LLMFactory.make(
                provider: workflow.llmProvider,
                model: workflow.llmModel,
                credentials: llmCredentials,
                thinking: workflow.llmThinking
            )
            let service = PolishService()
            finalText = try await service.run(
                request: PolishService.Request(
                    intent: intent,
                    rawText: rawText,
                    style: settings.activeStyle(),
                    attitude: attitude,
                    hostHint: hostHint
                ),
                engine: engine,
                redactionEnabled: settings.redactionEnabled
            )
            // 润色结果为空时回退原文，避免上屏空白。
            if finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finalText = rawText
            }
        }

        onPhase?(.done)
        let providerSummary = usedPolish
            ? "\(workflow.sttProvider.displayName) → \(workflow.llmProvider.displayName)"
            : workflow.sttProvider.displayName
        return Outcome(rawText: rawText, finalText: finalText, usedPolish: usedPolish, providerSummary: providerSummary)
    }

    public enum PipelineError: Error, LocalizedError {
        case sttNotConfigured(ProviderKind)
        case sttUnsupported(ProviderKind)
        case llmNotConfigured(ProviderKind)

        public var errorDescription: String? {
            switch self {
            case .sttNotConfigured(let provider):
                return "一阶段听音引擎（\(provider.displayName)）尚未配置 API Key，请到主 App「API 配置」页填写"
            case .sttUnsupported(let provider):
                return "\(provider.displayName) 的实时流式听写将在后续版本支持，当前请先切换到硅基流动 / DeepSeek / Groq"
            case .llmNotConfigured(let provider):
                return "二阶段润色引擎（\(provider.displayName)）尚未配置 API Key，请到主 App「API 配置」页填写，或关闭「二阶段润色」"
            }
        }
    }
}
