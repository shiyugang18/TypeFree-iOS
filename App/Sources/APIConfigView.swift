import SwiftUI
import TypeFreeCore

/// 「API 配置」页：服务商凭证保险箱 + 工作流混搭。
struct APIConfigView: View {
    @EnvironmentObject private var store: SettingsRepository
    @State private var editingProvider: ProviderKind?

    var body: some View {
        NavigationStack {
            List {
                Section("1. 服务商凭证保险箱") {
                    providerTiles
                }
                Section("2. 工作流与模型自由混搭") {
                    workflowCards
                }
                Section("3. 隐私与体验") {
                    privacyToggles
                }
            }
            .navigationTitle("API 配置")
            .sheet(item: $editingProvider) { kind in
                ProviderEditorView(kind: kind)
                    .environmentObject(store)
            }
        }
    }

    // MARK: - 保险箱瓷砖

    private var providerTiles: some View {
        ForEach(ProviderKind.allCases) { kind in
            Button {
                editingProvider = kind
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: iconName(for: kind))
                        .font(.system(size: 18))
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.displayName).font(.system(size: 15, weight: .medium))
                        Text(subtitle(for: kind))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.vault.isConfigured(kind) {
                        Text("已配置")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func iconName(for kind: ProviderKind) -> String {
        switch kind {
        case .deepseek: return "brain.head.profile"
        case .siliconflow: return "waveform"
        case .bailian: return "cloud"
        case .volcengine: return "flame"
        case .zhipu: return "text.bubble"
        case .gemini: return "sparkles"
        case .groq: return "hare"
        case .ollama: return "desktopcomputer"
        case .custom: return "wrench.and.screwdriver"
        }
    }

    private func subtitle(for kind: ProviderKind) -> String {
        let creds = store.vault.credentials(for: kind)
        if !creds.isEmpty {
            return ProviderDefaults.baseURL(for: kind).isEmpty ? "自定义端点" : ProviderDefaults.baseURL(for: kind)
        }
        return "未配置 · 点此填写"
    }

    // MARK: - 工作流

    private var workflowCards: some View {
        Group {
            workflowRow(
                title: "👂 听音转写引擎（一阶段）",
                role: .stt,
                model: Binding(
                    get: { store.settings.workflow.sttModel },
                    set: { newModel in store.update { $0.workflow.sttModel = newModel } }
                ),
                options: supportedSTTProviders,
                providerBinding: Binding(
                    get: { store.settings.workflow.sttProvider },
                    set: { newKind in
                        store.update {
                            $0.workflow.sttProvider = newKind
                            $0.workflow.sttModel = ProviderDefaults.sttModel(for: newKind)
                        }
                    }
                )
            )
            Toggle("🧠 二阶段润色（关闭 = 极速直出）", isOn: Binding(
                get: { store.settings.workflow.polishEnabled },
                set: { enabled in store.update { $0.workflow.polishEnabled = enabled } }
            ))
            if store.settings.workflow.polishEnabled {
                workflowRow(
                    title: "🧠 语义润色 / 帮写 / 快译模型（二阶段）",
                    role: .llm,
                    model: Binding(
                        get: { store.settings.workflow.llmModel },
                        set: { newModel in store.update { $0.workflow.llmModel = newModel } }
                    ),
                    options: ProviderKind.allCases,
                    providerBinding: Binding(
                        get: { store.settings.workflow.llmProvider },
                        set: { newKind in
                            store.update {
                                $0.workflow.llmProvider = newKind
                                $0.workflow.llmModel = ProviderDefaults.llmModel(for: newKind)
                            }
                        }
                    )
                )
                Picker("思考模式", selection: Binding(
                    get: { store.settings.workflow.llmThinking },
                    set: { newMode in store.update { $0.workflow.llmThinking = newMode } }
                )) {
                    ForEach(ThinkingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
            latencyTestButton
        }
    }

    private var supportedSTTProviders: [ProviderKind] {
        [.deepseek, .siliconflow, .zhipu, .groq, .custom]
    }

    private func workflowRow(
        title: String,
        role: AIRole,
        model: Binding<String>,
        options: [ProviderKind],
        providerBinding: Binding<ProviderKind>
    ) -> some View {
        let current = role == .stt
            ? store.settings.workflow.sttProvider
            : store.settings.workflow.llmProvider

        return VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .medium))
            Picker("服务商", selection: providerBinding) {
                ForEach(options, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            HStack {
                Text("模型").font(.system(size: 13)).foregroundStyle(.secondary)
                TextField("model", text: model)
                    .font(.system(size: 13))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("推荐") {
                    model.wrappedValue = role == .stt
                        ? ProviderDefaults.sttModel(for: current)
                        : ProviderDefaults.llmModel(for: current)
                }
                .font(.system(size: 12))
            }
        }
        .padding(.vertical, 4)
    }

    /// 1-Token 首字延迟测速（简化版：一次最小补全往返）。
    private var latencyTestButton: some View {
        LatencyTestButton(store: store)
    }

    private var privacyToggles: some View {
        Group {
            Toggle("🛡️ 端侧敏感信息脱敏", isOn: Binding(
                get: { store.settings.redactionEnabled },
                set: { enabled in store.update { $0.redactionEnabled = enabled } }
            ))
            Toggle("🫥 无痕模式（不记历史）", isOn: Binding(
                get: { store.settings.incognito },
                set: { enabled in store.update { $0.incognito = enabled } }
            ))
            Picker("历史留存", selection: Binding(
                get: { store.settings.historyDays },
                set: { days in store.update { $0.historyDays = days } }
            )) {
                Text("立即清除").tag(0)
                Text("3 天").tag(3)
                Text("7 天").tag(7)
                Text("30 天").tag(30)
                Text("永久").tag(-1)
            }
        }
    }
}

// MARK: - 延迟测速

struct LatencyTestButton: View {
    @ObservedObject var store: SettingsRepository
    @State private var isTesting = false
    @State private var result: String?

    var body: some View {
        Button {
            Task { await test() }
        } label: {
            HStack {
                if isTesting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text(isTesting ? "测速中…" : "⚡ 测试润色模型首字延迟")
            }
        }
        .disabled(isTesting)
        if let result {
            Text(result)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func test() async {
        isTesting = true
        result = nil
        defer { isTesting = false }

        let workflow = store.settings.workflow
        let credentials = store.vault.credentials(for: workflow.llmProvider)
        guard !credentials.isEmpty else {
            result = "请先配置 \(workflow.llmProvider.displayName) 的 Key"
            return
        }
        do {
            let engine = try LLMFactory.make(
                provider: workflow.llmProvider,
                model: workflow.llmModel,
                credentials: credentials,
                thinking: .off,
                temperature: 0
            )
            let started = Date()
            var firstDelta: String?
            for try await delta in engine.stream(messages: [ChatMessage(role: "user", content: "ping")]) {
                firstDelta = delta
                break
            }
            let elapsed = Int(Date().timeIntervalSince(started) * 1000)
            result = firstDelta != nil
                ? "✅ 首字延迟 \(elapsed) ms（\(workflow.llmProvider.displayName) · \(workflow.llmModel)）"
                : "⚠️ 连通但无输出（\(elapsed) ms）"
        } catch {
            result = "❌ \(error.localizedDescription)"
        }
    }
}
