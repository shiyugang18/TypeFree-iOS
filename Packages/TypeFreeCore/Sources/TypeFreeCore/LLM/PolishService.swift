import Foundation

/// 二阶段语义工作台：净写 / 帮写 / 快译 / 改写 / 问AI。
/// 提示词语义对齐上游 TypeFree 的五大意图。
public struct PolishService: Sendable {

    public enum Intent: String, Sendable {
        case dictate   // 🎙️ 口述净写
        case helpWrite // ✍️ 帮我写
        case translate // 🌐 快译
        case rewrite   // 🪄 选中文本改写
        case ask       // 🔍 问AI
    }

    public struct Request: Sendable {
        public let intent: Intent
        public let rawText: String
        public let style: StylePreset?
        public let attitude: AttitudeChip?
        public let translateTarget: TranslateTarget?
        public let hostHint: String? // 使用场景提示，如「微信聊天」

        public init(
            intent: Intent,
            rawText: String,
            style: StylePreset? = nil,
            attitude: AttitudeChip? = nil,
            translateTarget: TranslateTarget? = nil,
            hostHint: String? = nil
        ) {
            self.intent = intent
            self.rawText = rawText
            self.style = style
            self.attitude = attitude
            self.translateTarget = translateTarget
            self.hostHint = hostHint
        }
    }

    public init() {}

    // MARK: - Prompt 构造

    public func systemPrompt(for request: Request) -> String {
        var lines: [String] = []

        switch request.intent {
        case .dictate:
            lines.append("""
            你是中文语音输入润色引擎。用户给你一段语音识别的口语转写稿。你的任务：
            1. 删除“嗯、啊、呃、那个、就是说、然后”等无意义的口癖词；
            2. 识别口语改口纠正（如“明天三点，不对，四点”→ 以纠正后的说法为准）；
            3. 补全标点、合理断句；
            4. 严格保留说话人的原意、语气和信息量，不扩写、不增删事实；
            5. 数字、时间、金额用阿拉伯数字；
            6. 只输出润色后的文本，不要任何解释、前后缀或 Markdown。
            """)
        case .helpWrite:
            lines.append("""
            你是聊天回复起草助手，帮用户起草一条可以直接发送的回复。
            要求：自然、得体、像真人打字，不要书面腔和 AI 味；
            只输出回复正文，不要任何解释、引号或 Markdown。
            """)
        case .translate:
            lines.append("""
            你是专业翻译引擎。判断输入文本语言：若是中文则翻译成目标语言，否则翻译成中文。
            保留原意与语气，口语化表达自然地道。
            只输出译文，不要任何解释。
            """)
        case .rewrite:
            lines.append("""
            你是文本改写引擎。按用户要求改写给定文本，
            严格保留原意与关键信息，只输出改写结果，不要任何解释。
            """)
        case .ask:
            lines.append("""
            你是简洁准确的问答助手。直接回答问题，简明扼要，
            有把握时给出确定答案，不确定时如实说明。
            用纯文本回答，不要 Markdown 格式标记。
            """)
        }

        if let style = request.style {
            lines.append("文风要求：\(style.promptHint)")
        }
        if let hostHint = request.hostHint, !hostHint.isEmpty {
            lines.append("使用场景：\(hostHint)。请贴合该场景的语气。")
        }
        return lines.joined(separator: "\n")
    }

    public func userPrompt(for request: Request) -> String {
        switch request.intent {
        case .dictate, .ask:
            return request.rawText
        case .translate:
            let target = request.translateTarget?.promptName ?? "英文"
            return "目标语言：\(target)\n\n\(request.rawText)"
        case .rewrite:
            return "改写要求：\(request.rawText)\n\n（若上方只给了要求而未给原文，则原文为空，请直接按要求生成；否则改写原文。）"
        case .helpWrite:
            var parts: [String] = []
            if let attitude = request.attitude {
                parts.append("回复态度：\(attitude.label)（\(attitude.promptHint)）")
            }
            if !request.rawText.isEmpty {
                parts.append("我补充的口述内容：\(request.rawText)")
            }
            return parts.isEmpty ? "帮我起草一条自然的问候回复。" : parts.joined(separator: "\n")
        }
    }

    public func buildMessages(for request: Request) -> [ChatMessage] {
        [
            ChatMessage(role: "system", content: systemPrompt(for: request)),
            ChatMessage(role: "user", content: userPrompt(for: request))
        ]
    }

    // MARK: - 执行（脱敏 → LLM → 还原）

    /// 执行二阶段处理。自动应用端侧脱敏并在响应后还原。
    public func run(
        request: Request,
        engine: LLMEngine,
        redactionEnabled: Bool
    ) async throws -> String {
        let redactor = Redactor(enabled: redactionEnabled)
        let redacted = redactor.redact(request.rawText)

        var effective = request
        if redactionEnabled, redacted.sanitized != request.rawText {
            effective = Request(
                intent: request.intent,
                rawText: redacted.sanitized,
                style: request.style,
                attitude: request.attitude,
                translateTarget: request.translateTarget,
                hostHint: request.hostHint
            )
        }

        let messages = buildMessages(for: effective)
        var collected = ""
        for try await delta in engine.stream(messages: messages) {
            collected += delta
        }

        let cleaned = Self.trimOutput(collected)
        return redactionEnabled ? Redactor.restore(cleaned, replacements: redacted.replacements) : cleaned
    }

    /// 清理常见模型尾巴（代码围栏、前后引号）。
    public static func trimOutput(_ text: String) -> String {
        var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.hasPrefix("```") {
            if let firstNewline = output.firstIndex(of: "\n") {
                output = String(output[output.index(after: firstNewline)...])
            }
            if output.hasSuffix("```") {
                output = String(output[..<output.index(output.endIndex, offsetBy: -3)])
            }
            output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return output
    }
}
