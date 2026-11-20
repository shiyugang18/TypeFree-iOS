import XCTest
@testable import TypeFreeCore

final class ProviderVaultTests: XCTestCase {

    /// 每个测试用独立 suite，避免并行执行时共享存储互相覆盖。
    private func makeVault() -> ProviderVault {
        ProviderVault(suiteName: "tf-tests.\(UUID().uuidString)")
    }

    func testObfuscationRoundtrip() throws {
        let payload = try TypeFreeSettings.default.jsonData()
        let obfuscated = ProviderVault.obfuscate(payload)
        XCTAssertNotEqual(obfuscated, String(data: payload, encoding: .utf8))
        let restored = try XCTUnwrap(ProviderVault.deobfuscate(obfuscated))
        XCTAssertEqual(restored, payload)
    }

    func testSettingsRoundtrip() throws {
        var settings = TypeFreeSettings.default
        settings.credentials[.deepseek] = ProviderCredentials(apiKey: "sk-abc")
        settings.workflow.sttProvider = .siliconflow
        settings.workflow.sttModel = "FunAudioLLM/SenseVoiceSmall"

        let data = try settings.jsonData()
        let decoded = try TypeFreeSettings.decode(from: data)
        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.credentials[.deepseek]?.apiKey, "sk-abc")
    }

    func testApplyFullPlanSwitchesBothStages() {
        let vault = makeVault()
        vault.update { $0 = TypeFreeSettings.default } // 初始化
        vault.saveCredentials(ProviderCredentials(apiKey: "sk-x"), for: .siliconflow)
        vault.applyFullPlan(sttAndLLM: .siliconflow)

        let settings = vault.loadSettings()
        XCTAssertEqual(settings.workflow.sttProvider, .siliconflow)
        XCTAssertEqual(settings.workflow.sttModel, "FunAudioLLM/SenseVoiceSmall")
        XCTAssertEqual(settings.workflow.llmProvider, .siliconflow)
        XCTAssertEqual(settings.workflow.llmModel, "Qwen/Qwen2.5-7B-Instruct")
    }

    func testApplyLLMBrainKeepsSTT() {
        let vault = makeVault()
        vault.update { $0 = TypeFreeSettings.default }
        vault.applyFullPlan(sttAndLLM: .siliconflow) // 一阶段 = 硅基
        vault.applyLLMBrain(.deepseek)               // 二阶段换 DeepSeek

        let settings = vault.loadSettings()
        XCTAssertEqual(settings.workflow.sttProvider, .siliconflow)
        XCTAssertEqual(settings.workflow.llmProvider, .deepseek)
        XCTAssertEqual(settings.workflow.llmModel, "deepseek-chat")
    }

    func testApplyLLMBrainBackfillsSTTForDeepSeek() {
        let vault = makeVault()
        vault.update {
            $0 = TypeFreeSettings.default
            $0.workflow.sttProvider = .bailian // 不支持 REST 整包听写
        }
        vault.applyLLMBrain(.deepseek)
        let settings = vault.loadSettings()
        // 一阶段暂不支持时，DeepSeek（支持 REST 听写）应自动回填一阶段。
        XCTAssertEqual(settings.workflow.sttProvider, .deepseek)
        XCTAssertEqual(settings.workflow.llmProvider, .deepseek)
    }

    func testIsConfigured() {
        let vault = makeVault()
        vault.update { $0 = TypeFreeSettings.default }
        XCTAssertFalse(vault.isConfigured(.groq))
        vault.saveCredentials(ProviderCredentials(apiKey: "gsk-x"), for: .groq)
        XCTAssertTrue(vault.isConfigured(.groq))
    }
}
