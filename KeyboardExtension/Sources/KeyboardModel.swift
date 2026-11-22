import Foundation
import TypeFreeCore
import UIKit

/// 键盘扩展状态机：录音 → 转写 → 润色 → 上屏。
@MainActor
final class KeyboardModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case requestingPermission
        case recording
        case transcribing
        case polishing
    }

    enum Tab: Equatable {
        case voice
        case text
    }

    // MARK: - Published

    @Published var tab: Tab = .voice
    @Published var phase: Phase = .idle
    @Published var level: Float = 0
    @Published var errorMessage: String?
    @Published var statusHint: String = "按住麦克风说话，松手上屏"
    @Published var selectedAttitudeID: UUID?
    @Published var selectedStyleID: UUID?
    @Published var hasFullAccess = false
    @Published var incognito = false
    @Published var attitudes: [AttitudeChip] = AttitudeChip.defaults
    @Published var styles: [StylePreset] = StylePreset.builtins
    @Published var undoAvailable = false
    @Published var recordingSeconds: Int = 0

    // MARK: - Bridges

    weak var proxy: UITextDocumentProxy?
    var onDismiss: (() -> Void)?
    var onNextInputMode: (() -> Void)?

    // MARK: - Services

    let vault = ProviderVault()
    let recorder = AudioRecorder()
    let streamer = DocumentStreamer()
    private var recordingTimer: Timer?
    private var pendingIntent: PolishService.Intent = .dictate

    var activeStyle: StylePreset? {
        styles.first { $0.id == selectedStyleID } ?? settings.activeStyle()
    }

    private var settings: TypeFreeSettings {
        vault.loadSettings()
    }

    var selectedAttitude: AttitudeChip? {
        attitudes.first { $0.id == selectedAttitudeID }
    }

    var statusText: String {
        switch phase {
        case .idle: return statusHint
        case .requestingPermission: return "正在请求麦克风权限…"
        case .recording: return "正在聆听… 轻点 ✕ 取消"
        case .transcribing: return "识别中…"
        case .polishing: return incognito ? "润色中…" : "润色中（脱敏已开启）…"
        }
    }

    var isBusy: Bool {
        phase == .transcribing || phase == .polishing
    }

    init() {
        reloadSettings()
        recorder.levelHandler = { [weak self] level in
            DispatchQueue.main.async {
                self?.level = level
            }
        }
    }

    func reloadSettings() {
        let settings = self.settings
        incognito = settings.incognito
        attitudes = settings.attitudes.isEmpty ? AttitudeChip.defaults : settings.attitudes
        styles = settings.styles.isEmpty ? StylePreset.builtins : settings.styles
        selectedStyleID = settings.activeStyle()?.id
    }

    func refreshContext() {
        reloadSettings()
    }

    // MARK: - 录音控制

    func beginRecording(intent: PolishService.Intent) {
        guard !isBusy else { return }
        pendingIntent = intent
        errorMessage = nil
        guard hasFullAccess else {
            errorMessage = "语音听写需要「允许完全访问」：设置 → 键盘 → TypeFree 语音键盘 → 打开允许完全访问"
            return
        }
        phase = .requestingPermission
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await recorder.requestPermission()
            guard granted else {
                self.phase = .idle
                self.errorMessage = "麦克风权限被拒绝，请在系统设置中允许 TypeFree 使用麦克风"
                return
            }
            do {
                try recorder.start()
                self.phase = .recording
                self.startRecordingTimer()
            } catch {
                self.phase = .idle
                self.errorMessage = "录音启动失败：\(error.localizedDescription)"
            }
        }
    }

    func endRecording() {
        guard phase == .recording else { return }
        stopRecordingTimer()
        level = 0
        guard let wav = recorder.stopAndBuildWAV(), !wav.isEmpty else {
            phase = .idle
            statusHint = "没有录到声音，再试一次"
            return
        }
        runPipeline(wav: wav, intent: pendingIntent, attitude: selectedAttitude)
    }

    func cancelRecording() {
        guard phase == .recording else { return }
        stopRecordingTimer()
        recorder.discard()
        level = 0
        phase = .idle
        statusHint = "已取消"
    }

    /// ⚡ 免开口直接生成（帮写：态度 + 空补充）。
    func quickGenerate() {
        guard !isBusy else { return }
        guard hasFullAccess else {
            errorMessage = "需要「允许完全访问」才能联网生成"
            return
        }
        runHelpWrite(rawDetail: "", attitude: selectedAttitude)
    }

    // MARK: - 管线

    private func runPipeline(wav: Data, intent: PolishService.Intent, attitude: AttitudeChip?) {
        phase = .transcribing
        let pipeline = VoicePipeline(settings: settings, vault: vault, hostHint: hostAppHint)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let outcome = try await pipeline.run(
                    wavData: wav,
                    intent: intent,
                    attitude: attitude,
                    onPhase: { phase in
                        Task { @MainActor in
                            switch phase {
                            case .transcribing: self.phase = .transcribing
                            case .polishing: self.phase = .polishing
                            default: break
                            }
                        }
                    },
                    onRawText: { raw in
                        // 先插草稿：识别一出就上屏，润色完成后原地替换。
                        Task { @MainActor in
                            if let proxy = self.proxy {
                                self.streamer.insertDraft(raw, proxy: proxy)
                            }
                        }
                    }
                )
                if let proxy = self.proxy {
                    if outcome.usedPolish {
                        self.streamer.finalize(outcome.finalText, proxy: proxy)
                    } else {
                        // 直出：草稿已在屏上，无需再动。
                        self.streamer.reset()
                    }
                }
                self.undoAvailable = !self.streamer.lastFinal.isEmpty
                self.phase = .idle
                self.statusHint = self.incognito ? "完成（无痕模式，未记录历史）" : "完成"
                if !self.incognito {
                    HistoryStore(vault: self.vault).append(HistoryItem(
                        intent: intent == .dictate ? "口述净写" : "帮写",
                        rawText: outcome.rawText,
                        finalText: outcome.finalText,
                        providerSummary: outcome.providerSummary
                    ))
                }
            } catch {
                self.streamer.reset()
                self.phase = .idle
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// 纯 LLM 帮写（不经过 STT）。
    private func runHelpWrite(rawDetail: String, attitude: AttitudeChip?) {
        phase = .polishing
        let settingsSnapshot = settings
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let credentials = self.vault.credentials(for: settingsSnapshot.workflow.llmProvider)
                guard !credentials.isEmpty else {
                    throw VoicePipeline.PipelineError.llmNotConfigured(settingsSnapshot.workflow.llmProvider)
                }
                let engine = try LLMFactory.make(
                    provider: settingsSnapshot.workflow.llmProvider,
                    model: settingsSnapshot.workflow.llmModel,
                    credentials: credentials,
                    thinking: settingsSnapshot.workflow.llmThinking
                )
                let result = try await PolishService().run(
                    request: PolishService.Request(
                        intent: .helpWrite,
                        rawText: rawDetail,
                        style: self.activeStyle,
                        attitude: attitude,
                        hostHint: self.hostAppHint
                    ),
                    engine: engine,
                    redactionEnabled: settingsSnapshot.redactionEnabled
                )
                if let proxy = self.proxy {
                    self.streamer.commitDirect(result, proxy: proxy)
                }
                self.undoAvailable = true
                self.phase = .idle
                self.statusHint = "已生成，可直接发送"
            } catch {
                self.phase = .idle
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func undoLast() {
        guard let proxy else { return }
        streamer.undoFinal(proxy: proxy)
        undoAvailable = !streamer.lastFinal.isEmpty
    }

    // MARK: - 其他

    func switchTab() {
        guard !isBusy else { return }
        tab = (tab == .voice) ? .text : .voice
    }

    func dismissKeyboard() {
        onDismiss?()
    }

    func advanceInputMode() {
        onNextInputMode?()
    }

    private func startRecordingTimer() {
        recordingSeconds = 0
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordingSeconds += 1
                // 超过 60 秒自动收尾（对齐上游超长语音轮换的简化版）。
                if let self, self.recordingSeconds >= 60, self.phase == .recording {
                    self.endRecording()
                }
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    /// 宿主 App 场景提示（v0.1 通用提示，Phase 2 做按 App 绑定文风）。
    private var hostAppHint: String? { nil }
}
