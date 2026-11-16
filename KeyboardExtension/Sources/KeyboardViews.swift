import SwiftUI
import TypeFreeCore

/// 键盘根视图：完全访问引导卡 / 语音面板 / QWERTY + 底部工具条。
struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 0) {
            if !model.hasFullAccess {
                FullAccessCard(model: model)
            } else if model.tab == .voice {
                VoicePanelView(model: model)
            } else {
                QWERTYView(model: model)
            }
            BottomToolbar(model: model)
        }
        .background(Color(UIColor.systemBackground))
        .environment(\.sizeCategory, .large)
    }
}

// MARK: - 完全访问引导

struct FullAccessCard: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 10) {
            Text("🎙️ 语音听写需要「允许完全访问」")
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text("设置 → 键盘 → TypeFree 语音键盘")
                Text("打开「允许完全访问」(Allow Full Access)")
                Text("音频只会发送给你自己配置的 API 服务商")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                model.advanceInputMode()
            } label: {
                Text("先切换到系统键盘 ›")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - 语音面板

struct VoicePanelView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 8) {
            topBar
            attitudeChips
            micArea
            statusAndError
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            styleMenu
            Text(model.statusText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if model.undoAvailable {
                Button {
                    model.undoLast()
                } label: {
                    Label("撤回", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    /// 文风胶囊菜单。
    private var styleMenu: some View {
        Menu {
            Section("文风") {
                ForEach(model.styles) { style in
                    Button {
                        model.selectedStyleID = style.id
                    } label: {
                        if style.id == model.activeStyle?.id {
                            Label(style.name, systemImage: "checkmark")
                        } else {
                            Text(style.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text(model.activeStyle?.name ?? "文风")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.14))
            .clipShape(Capsule())
        }
        .fixedSize()
    }

    /// 帮写态度芯片行。
    private var attitudeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.attitudes) { chip in
                    Button {
                        model.selectedAttitudeID = (model.selectedAttitudeID == chip.id) ? nil : chip.id
                    } label: {
                        Text("\(chip.emoji) \(chip.label)")
                            .font(.system(size: 12))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                model.selectedAttitudeID == chip.id
                                    ? Color.accentColor
                                    : Color(UIColor.secondarySystemBackground)
                            )
                            .foregroundStyle(model.selectedAttitudeID == chip.id ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Text("✍️ 选中态度后：按住麦克风说细节，或点 ⚡ 直接生成")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            }
            .padding(.vertical, 2)
        }
    }

    /// 中央麦克风区。
    private var micArea: some View {
        ZStack {
            HStack {
                if model.phase == .recording {
                    Button {
                        model.cancelRecording()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("\(model.recordingSeconds)s")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44)
                    Spacer()
                } else {
                    Spacer()
                }
            }

            if model.phase == .recording {
                LevelBars(level: model.level)
                    .frame(width: 160, height: 36)
            }

            HStack(spacing: 14) {
                Spacer()
                if model.selectedAttitudeID != nil && !model.isBusy && model.phase != .recording {
                    Button {
                        model.quickGenerate()
                    } label: {
                        Label("⚡ 直接生成", systemImage: "bolt.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.16))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                HoldToTalkButton(
                    onPressBegan: { model.beginRecording(intent: .dictate) },
                    onPressEnded: { model.endRecording() },
                    onPressCancelled: { model.cancelRecording() }
                ) {
                    VStack(spacing: 3) {
                        Image(systemName: model.isBusy ? "hourglass" : "mic.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(model.isBusy ? Color.gray : Color.white)
                        Text(holdButtonCaption)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(model.isBusy ? Color.gray : Color.white.opacity(0.9))
                    }
                    .frame(width: 86, height: 86)
                    .background(
                        Circle().fill(
                            model.phase == .recording
                                ? Color.red
                                : (model.isBusy ? Color(UIColor.tertiarySystemFill) : Color.accentColor)
                        )
                    )
                    .scaleEffect(model.phase == .recording ? 1.06 : 1.0)
                }
                .disabled(model.isBusy)
                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var holdButtonCaption: String {
        switch model.phase {
        case .recording: return "松手上屏"
        case .transcribing, .polishing: return "处理中"
        default: return "按住说话"
        }
    }

    private var statusAndError: some View {
        VStack(spacing: 4) {
            if let error = model.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            } else if model.incognito {
                Text("🫥 无痕模式：不记录历史")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 18)
    }
}

/// 录音电平条。
struct LevelBars: View {
    let level: Float

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<9, id: \.self) { index in
                let threshold = Float(index) / 9.0
                let active = level >= threshold * 0.5
                Capsule()
                    .fill(active ? Color.accentColor : Color(UIColor.tertiarySystemFill))
                    .frame(width: 8, height: CGFloat(10 + index * 3))
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
    }
}
