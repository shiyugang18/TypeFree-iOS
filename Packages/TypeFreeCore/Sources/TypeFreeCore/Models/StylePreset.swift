import Foundation

/// 文风预设（对齐上游「自然精炼 / 商务得体 / 极简要点 / 俏皮社交 / 学术严谨」）。
public struct StylePreset: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// 追加到润色 system prompt 的风格指令。
    public var promptHint: String
    public var isBuiltin: Bool

    public init(id: UUID = UUID(), name: String, promptHint: String, isBuiltin: Bool = false) {
        self.id = id
        self.name = name
        self.promptHint = promptHint
        self.isBuiltin = isBuiltin
    }

    public static let builtins: [StylePreset] = [
        StylePreset(name: "自然精炼", promptHint: "语言自然流畅、干净利落，去掉冗余但保留口语的亲切感。", isBuiltin: true),
        StylePreset(name: "商务得体", promptHint: "使用专业、礼貌、得体的商务语气，措辞严谨稳重。", isBuiltin: true),
        StylePreset(name: "极简要点", promptHint: "压缩为最精简的要点表达，短句、分点、无废话。", isBuiltin: true),
        StylePreset(name: "俏皮社交", promptHint: "轻松俏皮的社交媒体语气，可以用适度的表情符号，但不油腻。", isBuiltin: true),
        StylePreset(name: "学术严谨", promptHint: "严谨的书面学术表达，逻辑清晰，用词准确，避免口语化。", isBuiltin: true)
    ]
}

/// 「帮写」态度芯片（对齐上游 6 枚自然平视日常态度）。
public struct AttitudeChip: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var emoji: String
    public var label: String
    /// 注入帮写 prompt 的态度描述。
    public var promptHint: String

    public init(id: UUID = UUID(), emoji: String, label: String, promptHint: String) {
        self.id = id
        self.emoji = emoji
        self.label = label
        self.promptHint = promptHint
    }

    public static let defaults: [AttitudeChip] = [
        AttitudeChip(emoji: "👌", label: "行 / 好的", promptHint: "爽快答应，简洁直接"),
        AttitudeChip(emoji: "🙅", label: "算了 / 婉拒", promptHint: "礼貌但坚定地婉拒，给出简短理由，不卑不亢"),
        AttitudeChip(emoji: "🤔", label: "啥情况 / 追问", promptHint: "表达疑惑并追问细节，语气好奇而非指责"),
        AttitudeChip(emoji: "😂", label: "接梗 / 调侃", promptHint: "接住对方的梗，轻松调侃，幽默但不过火"),
        AttitudeChip(emoji: "⚡", label: "硬气回怼 / 催办", promptHint: "立场强硬、直接了当，必要时催促对方尽快行动"),
        AttitudeChip(emoji: "💼", label: "正式得体", promptHint: "正式、得体、完整的表达，适合工作场合")
    ]
}

/// 快译目标语言。
public enum TranslateTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case english = "English"
    case japanese = "日本語"
    case korean = "한국어"
    case chinese = "中文"

    public var id: String { rawValue }

    public var promptName: String {
        switch self {
        case .english: return "英文"
        case .japanese: return "日文"
        case .korean: return "韩文"
        case .chinese: return "中文"
        }
    }
}
