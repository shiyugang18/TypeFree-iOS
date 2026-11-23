import SwiftUI
import UIKit
import TypeFreeCore

/// 「听写试场」：在主 App 内直接试跑语音管线（不依赖键盘扩展）。
struct PlaygroundView: View {
    @EnvironmentObject private var store: SettingsRepository

    @StateObject private var engine = PlaygroundModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                phaseBanner

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(engine.resultText.isEmpty
                             ? "按住下方麦克风说话，识别与润色结果会显示在这里。"
                             : engine.resultText)
                            .font(.system(size: 15))
                            .foregroundStyle(engine.resultText.isEmpty ? .secondary : .primary)
                        if !engine.rawText.isEmpty, engine.rawText != engine.resultText {
                            Text("🎙️ 原始转写：\(engine.rawText)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let error = engine.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if !engine.resultText.isEmpty {
                    HStack {
                        Button {
                            UIPasteboard.general.string = engine.resultText
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        Button {
                            engine.resultText = ""
                            engine.rawText = ""
                        } label: {
                            Label("清空", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                HoldToTalkButton(
                    onPressBegan: { engine.beginRecording() },
                    onPressEnded: { engine.endRecording() },
                    onPressCancelled: { engine.cancelRecording() }
                ) {
                    VStack(spacing: 4) {
                        Image(systemName: engine.phase == .recording ? "stop.fill" : (engine.isBusy ? "hourglass" : "mic.fill"))
                            .font(.system(size: 30, weight: .semibold))
                        Text(engine.phase == .recording ? "松手上屏" : (engine.isBusy ? "处理中…" : "按住说话"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 104, height: 104)
                    .background(Circle().fill(engine.phase == .recording ? Color.red : Color.accentColor))
                }
                .padding(.bottom, 12)
            }
            .padding(16)
            .navigationTitle("听写试场")
            .onAppear { engine.store = store }
        }
    }

    @ViewBuilder
    private var phaseBanner: some View {
        let workflow = store.settings.workflow
        HStack {
            Text("👂 \(workflow.sttProvider.displayName)")
            Text("→")
            Text(workflow.polishEnabled ? "🧠 \(workflow.llmProvider.displayName)" : "🚀 直出")
            Spacer()
            Text(phaseText)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .padding(10)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var phaseText: String {
        switch engine.phase {
        case .idle: return "待命"
        case .requestingPermission: return "请求权限…"
        case .recording: return "聆听中"
        case .transcribing: return "识别中…"
        case .polishing: return "润色中…"
        }
    }
}

/// 试场视图模型（与键盘 KeyboardModel 共用 VoicePipeline，但输出进编辑区）。
@MainActor
final class PlaygroundModel: ObservableObject {
    enum Phase { case idle, requestingPermission, recording, transcribing, polishing }

    @Published var phase: Phase = .idle
    @Published var errorMessage: String?
    @Published var resultText = ""
    @Published var rawText = ""

    var store: SettingsRepository?
    private let recorder = AudioRecorder()

    init() {
        recorder.levelHandler = { _ in }
    }

    var isBusy: Bool { phase == .transcribing || phase == .polishing }

    func beginRecording() {
        guard !isBusy else { return }
        errorMessage = nil
        phase = .requestingPermission
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await recorder.requestPermission()
            guard granted else {
                self.phase = .idle
                self.errorMessage = "麦克风权限被拒绝"
                return
            }
            do {
                try recorder.start()
                self.phase = .recording
            } catch {
                self.phase = .idle
                self.errorMessage = "录音启动失败：\(error.localizedDescription)"
            }
        }
    }

    func endRecording() {
        guard phase == .recording else { return }
        guard let store else { return }
        guard let wav = recorder.stopAndBuildWAV() else {
            phase = .idle
            errorMessage = "没有录到声音"
            return
        }
        run(wav: wav, store: store)
    }

    func cancelRecording() {
        guard phase == .recording else { return }
        recorder.discard()
        phase = .idle
    }

    private func run(wav: Data, store: SettingsRepository) {
        phase = .transcribing
        let settings = store.settings
        let vault = store.vault
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let pipeline = VoicePipeline(settings: settings, vault: vault)
                let outcome = try await pipeline.run(wavData: wav, intent: .dictate)
                self.rawText = outcome.rawText
                self.resultText = outcome.finalText
                self.phase = .idle
                if outcome.finalText.isEmpty {
                    self.errorMessage = "没有识别到人声：请按住不放，说完再松手"
                }
                if !settings.incognito {
                    HistoryStore(vault: vault).append(HistoryItem(
                        intent: "试场听写",
                        rawText: outcome.rawText,
                        finalText: outcome.finalText,
                        providerSummary: outcome.providerSummary
                    ))
                }
            } catch {
                self.phase = .idle
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
