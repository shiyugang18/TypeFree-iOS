import SwiftUI
import TypeFreeCore

/// 单个服务商的凭证编辑页（保险箱瓷缺点入）。
struct ProviderEditorView: View {
    let kind: ProviderKind
    @EnvironmentObject private var store: SettingsRepository
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var arkAPIKey = ""
    @State private var asrAccessToken = ""
    @State private var asrAppID = ""
    @State private var baseURL = ""
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(intro(for: kind))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Section("凭证") {
                    ForEach(kind.credentialFields, id: \.self) { field in
                        credentialFieldRow(field)
                    }
                }
                if kind != .ollama {
                    Section("高级：覆盖 Base URL（可选）") {
                        TextField(ProviderDefaults.baseURL(for: kind), text: $baseURL)
                            .font(.system(size: 13))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
                Section {
                    Button {
                        store.saveCredentials(collect(), for: kind)
                        dismiss()
                    } label: {
                        Text("💾 保存凭证").frame(maxWidth: .infinity)
                    }
                }
                actionButtons
            }
            .navigationTitle(kind.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private var actionButtons: some View {
        Section("一键方案") {
            Button {
                store.saveCredentials(collect(), for: kind)
                store.vault.applyFullPlan(sttAndLLM: kind)
                store.reload()
                dismiss()
            } label: {
                Label("🚀 一键设为当前主力方案（听音 + 大脑）", systemImage: "bolt.fill")
                    .font(.system(size: 14, weight: .medium))
            }
            .disabled(!ProviderDefaults.supportsRESTSTT(kind) && kind != .custom)
            Button {
                store.saveCredentials(collect(), for: kind)
                store.vault.applyLLMBrain(kind)
                store.reload()
                dismiss()
            } label: {
                Label("🧠 仅设为文本大脑（保留当前听音通道）", systemImage: "brain")
                    .font(.system(size: 14, weight: .medium))
            }
        }
    }

    // MARK: - 字段

    @ViewBuilder
    private func credentialFieldRow(_ field: CredentialField) -> some View {
        switch field {
        case .apiKey:
            SecureFieldWithReveal(title: field.displayName, text: $apiKey)
        case .arkAPIKey:
            SecureFieldWithReveal(title: field.displayName, text: $arkAPIKey)
        case .asrAccessToken:
            SecureFieldWithReveal(title: field.displayName, text: $asrAccessToken)
        case .asrAppID:
            TextField(field.displayName, text: $asrAppID)
                .keyboardType(.numberPad)
        case .baseURL:
            TextField(field.displayName, text: $baseURL)
                .font(.system(size: 13))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    // MARK: - 数据

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        let creds = store.vault.credentials(for: kind)
        apiKey = creds.apiKey
        arkAPIKey = creds.arkAPIKey
        asrAccessToken = creds.asrAccessToken
        asrAppID = creds.asrAppID
        baseURL = creds.baseURL
    }

    private func collect() -> ProviderCredentials {
        ProviderCredentials(
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            arkAPIKey: arkAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            asrAccessToken: asrAccessToken.trimmingCharacters(in: .whitespacesAndNewlines),
            asrAppID: asrAppID.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func intro(for kind: ProviderKind) -> String {
        switch kind {
        case .deepseek:
            return "1 把 DeepSeek Key 通吃全链路：官方 ASR（/v1/tools/asr）负责听音，deepseek-chat 负责润色 / 帮写 / 快译。"
        case .siliconflow:
            return "硅基流动提供免费的 SenseVoiceSmall 整包听音，与 Qwen 系列润色模型。"
        case .bailian:
            return "阿里云百炼：一个 sk- Key 即可驱动实时流式听写（Phase 2 接入 iOS）与 Qwen 大模型。"
        case .volcengine:
            return "火山引擎：豆包语音（SeedASR 流式，Phase 2）与火山方舟（豆包 LLM）分属两个控制台，凭证分开填写。"
        case .gemini:
            return "Google Gemini：v1beta REST。听音直出将在 Phase 2 支持，当前可作二阶段大脑。"
        case .groq:
            return "Groq：whisper-large-v3 极速听音，海外免翻。"
        case .ollama:
            return "本地 Ollama：默认 http://127.0.0.1:11434/v1，全离线零成本。"
        case .custom:
            return "任意 OpenAI 兼容网关：填 Base URL + Key。若用于听音，端点需兼容 /audio/transcriptions。"
        }
    }
}

/// 带小眼睛的密钥输入框。
struct SecureFieldWithReveal: View {
    let title: String
    @Binding var text: String
    @State private var reveal = false

    var body: some View {
        HStack {
            if reveal {
                TextField(title, text: $text)
                    .font(.system(size: 13))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(title, text: $text)
                    .font(.system(size: 13))
            }
            Button {
                reveal.toggle()
            } label: {
                Image(systemName: reveal ? "eye.slash" : "eye")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
