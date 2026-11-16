import Foundation

/// App Group 共享容器中的设置仓库。
///
/// 主 App 与键盘扩展通过同一个 `UserDefaults(suiteName:)` 读取同一份设置 JSON。
/// v0.1 存储策略：整体 JSON 做 XOR + Base64 混淆后落盘（避免明文 Key 直接躺在 plist 里）。
/// Phase 2 计划升级为 Keychain 共享访问组（`keychain-access-groups`）加密存储。
public final class ProviderVault: @unchecked Sendable {

    public static let appGroupID = "group.com.typefree.ios.shared"
    static let storageKey = "tf.settings.v1"

    /// 32 字节混淆密钥（本机离线混淆，非强加密；见 README「隐私与安全」说明）。
    static let obfuscationKey: [UInt8] = Array("TypeFree-iOS-Local-Obfuscation-v1".utf8)

    let defaults: UserDefaults?

    public init(suiteName: String = ProviderVault.appGroupID) {
        self.defaults = UserDefaults(suiteName: suiteName)
    }

    // MARK: - Load / Save

    public func loadSettings() -> TypeFreeSettings {
        guard let defaults else { return .default }
        guard let raw = defaults.string(forKey: Self.storageKey) else { return .default }
        guard let data = Self.deobfuscate(raw) else { return .default }
        return (try? TypeFreeSettings.decode(from: data)) ?? .default
    }

    public func saveSettings(_ settings: TypeFreeSettings) {
        guard let defaults else { return }
        guard let data = try? settings.jsonData() else { return }
        defaults.set(Self.obfuscate(data), forKey: Self.storageKey)
    }

    public func update(_ mutate: (inout TypeFreeSettings) -> Void) {
        var settings = loadSettings()
        mutate(&settings)
        saveSettings(settings)
    }

    // MARK: - Credentials

    public func credentials(for kind: ProviderKind) -> ProviderCredentials {
        loadSettings().credentials[kind] ?? ProviderCredentials()
    }

    public func saveCredentials(_ credentials: ProviderCredentials, for kind: ProviderKind) {
        update { $0.credentials[kind] = credentials }
    }

    public func isConfigured(_ kind: ProviderKind) -> Bool {
        !credentials(for: kind).isEmpty
    }

    /// 主力方案一键配置（对齐上游「🚀 一键设为当前主力方案」）。
    public func applyFullPlan(sttAndLLM kind: ProviderKind) {
        update { settings in
            settings.workflow.sttProvider = kind
            settings.workflow.sttModel = ProviderDefaults.sttModel(for: kind)
            settings.workflow.llmProvider = kind
            settings.workflow.llmModel = ProviderDefaults.llmModel(for: kind)
        }
    }

    /// 仅更换文本大脑（对齐上游「🧠 一键设为文本大脑」），保留一阶段听音通道。
    public func applyLLMBrain(_ kind: ProviderKind) {
        update { settings in
            settings.workflow.llmProvider = kind
            settings.workflow.llmModel = ProviderDefaults.llmModel(for: kind)
            // 若一阶段尚未配置可用引擎，而该服务商恰好支持 REST 听写（如 DeepSeek ASR），顺带回填。
            if !ProviderDefaults.supportsRESTSTT(settings.workflow.sttProvider),
               ProviderDefaults.supportsRESTSTT(kind) {
                settings.workflow.sttProvider = kind
                settings.workflow.sttModel = ProviderDefaults.sttModel(for: kind)
            }
        }
    }

    // MARK: - Obfuscation

    static func obfuscate(_ data: Data) -> String {
        let bytes = [UInt8](data)
        let xored = bytes.enumerated().map { $0.element ^ obfuscationKey[$0.offset % obfuscationKey.count] }
        return Data(xored).base64EncodedString()
    }

    static func deobfuscate(_ string: String) -> Data? {
        guard let xored = Data(base64Encoded: string) else { return nil }
        let bytes = [UInt8](xored)
        let restored = bytes.enumerated().map { $0.element ^ obfuscationKey[$0.offset % obfuscationKey.count] }
        return Data(restored)
    }
}
