import Foundation

/// 全量应用设置。整体作为一个 Codable 对象存入 App Group，主 App 与键盘扩展共享同一份。
public struct TypeFreeSettings: Codable, Equatable, Sendable {
    public var workflow: WorkflowConfig
    public var credentials: [ProviderKind: ProviderCredentials]
    public var styles: [StylePreset]
    public var attitudes: [AttitudeChip]
    public var activeStyleID: UUID?
    /// 端侧敏感信息脱敏（上云前替换占位符、本地还原）。
    public var redactionEnabled: Bool
    /// 无痕模式：暂停历史记录与一切本地学习写入。
    public var incognito: Bool
    /// 历史记录留存天数（0 = 不留存，-1 = 永久）。
    public var historyDays: Int

    public init(
        workflow: WorkflowConfig = WorkflowConfig(),
        credentials: [ProviderKind: ProviderCredentials] = [:],
        styles: [StylePreset] = StylePreset.builtins,
        attitudes: [AttitudeChip] = AttitudeChip.defaults,
        redactionEnabled: Bool = true,
        incognito: Bool = false,
        historyDays: Int = 7
    ) {
        self.workflow = workflow
        self.credentials = credentials
        self.styles = styles
        self.attitudes = attitudes
        self.redactionEnabled = redactionEnabled
        self.incognito = incognito
        self.historyDays = historyDays
    }

    public static let `default` = TypeFreeSettings()

    public func activeStyle() -> StylePreset? {
        if let id = activeStyleID {
            return styles.first { $0.id == id }
        }
        return styles.first
    }

    /// JSON 编码（Vault 内部使用）。
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.sortedKeys = true
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> TypeFreeSettings {
        try JSONDecoder().decode(TypeFreeSettings.self, from: data)
    }
}

/// 历史记录条目。
public struct HistoryItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var intent: String
    public var rawText: String
    public var finalText: String
    public var providerSummary: String

    public init(id: UUID = UUID(), date: Date = Date(), intent: String, rawText: String, finalText: String, providerSummary: String) {
        self.id = id
        self.date = date
        self.intent = intent
        self.rawText = rawText
        self.finalText = finalText
        self.providerSummary = providerSummary
    }
}
