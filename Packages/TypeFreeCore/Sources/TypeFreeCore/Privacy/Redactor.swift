import Foundation

/// 端侧敏感信息脱敏器（对齐上游 `SensitiveDataRedactor`）。
/// 上云前把手机号 / 身份证 / 银行卡 / 微信号替换为 `[手机号_1]` 式占位符，
/// LLM 响应回来后在本地无损还原。
public struct Redactor: Sendable {

    public struct Result: Equatable, Sendable {
        public let sanitized: String
        public let replacements: [String: String] // 占位符 -> 原文
    }

    let redactPhone: Bool
    let redactIDCard: Bool
    let redactBankCard: Bool
    let redactWeChat: Bool

    public init(
        redactPhone: Bool = true,
        redactIDCard: Bool = true,
        redactBankCard: Bool = true,
        redactWeChat: Bool = true
    ) {
        self.redactPhone = redactPhone
        self.redactIDCard = redactIDCard
        self.redactBankCard = redactBankCard
        self.redactWeChat = redactWeChat
    }

    public init(enabled: Bool) {
        self.init(redactPhone: enabled, redactIDCard: enabled, redactBankCard: enabled, redactWeChat: enabled)
    }

    // MARK: - Patterns

    static let idCardRegex = try? NSRegularExpression(
        pattern: #"(?<!\d)\d{17}[\dXx](?!\d)"#)
    static let bankCardRegex = try? NSRegularExpression(
        pattern: #"(?<!\d)\d{13,19}(?!\d)"#)
    static let phoneRegex = try? NSRegularExpression(
        pattern: #"(?<!\d)1[3-9]\d{9}(?!\d)"#)
    static let weChatRegex = try? NSRegularExpression(
        pattern: #"(微信|vx|VX|wx|WX|威信)[:：\s]*[a-zA-Z][a-zA-Z0-9_-]{5,19}"#)

    // MARK: - API

    /// 脱敏：返回净化文本与占位符映射。
    public func redact(_ text: String) -> Result {
        var working = text
        var replacements: [String: String] = [:]
        var counters: [String: Int] = [:]

        func replaceAll(_ regex: NSRegularExpression?, label: String) {
            guard let regex else { return }
            let ns = working as NSString
            let matches = regex.matches(in: working, range: NSRange(location: 0, length: ns.length))
                .reversed() // 从后往前替换，保持 range 有效
            for match in matches {
                let original = ns.substring(with: match.range)
                let seq = (counters[label] ?? 0) + 1
                counters[label] = seq
                let placeholder = "[\(label)_\(seq)]"
                replacements[placeholder] = original
                working = (working as NSString).replacingCharacters(in: match.range, with: placeholder)
            }
        }

        // 顺序很重要：先长后短，避免号码被子模式吞掉。
        if redactIDCard { replaceAll(Self.idCardRegex, label: "身份证") }
        if redactBankCard { replaceAll(Self.bankCardRegex, label: "银行卡") }
        if redactPhone { replaceAll(Self.phoneRegex, label: "手机号") }
        if redactWeChat { replaceAll(Self.weChatRegex, label: "微信号") }

        return Result(sanitized: working, replacements: replacements)
    }

    /// 还原：把 LLM 响应里的占位符换回原文。
    public static func restore(_ text: String, replacements: [String: String]) -> String {
        var working = text
        for (placeholder, original) in replacements.sorted(by: { $0.key.count > $1.key.count }) {
            working = working.replacingOccurrences(of: placeholder, with: original)
        }
        return working
    }
}
