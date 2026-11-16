import SwiftUI
import TypeFreeCore

/// 底部工具条：切键盘 / 语音⇄打字 / 空格 / 回车 / 收起。
struct BottomToolbar: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        HStack(spacing: 8) {
            toolbarButton(icon: "globe", label: "") {
                model.advanceInputMode()
            }
            toolbarButton(icon: model.tab == .voice ? "keyboard" : "mic.fill", label: "") {
                model.switchTab()
            }
            Button {
                model.proxy?.insertText(" ")
            } label: {
                Text("空格")
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, maxHeight: 34)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            toolbarButton(icon: "", label: "⏎") {
                model.proxy?.insertText("\n")
            }
            toolbarButton(icon: "chevron.down", label: "") {
                model.dismissKeyboard()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func toolbarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if icon.isEmpty {
                    Text(label).font(.system(size: 15, weight: .medium))
                } else {
                    Image(systemName: icon).font(.system(size: 15))
                }
            }
            .frame(width: 40, height: 34)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - QWERTY 键盘

struct QWERTYView: View {
    @ObservedObject var model: KeyboardModel
    @State private var shift = true
    @State private var symbolMode = false

    private let letterRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]
    private let symbolRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "¥", "@", "&", "\""],
        [".", ",", "?", "!", "'"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { rowIndex in
                row(at: rowIndex)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }

    private func row(at index: Int) -> some View {
        let rows = symbolMode ? symbolRows : letterRows
        let keys = index < rows.count ? rows[index] : []

        return HStack(spacing: 5) {
            if index == 2 {
                sideKey(title: symbolMode ? "ABC" : "123") {
                    symbolMode.toggle()
                }
            }
            ForEach(keys, id: \.self) { key in
                keyButton(title: display(for: key)) {
                    insert(key)
                }
            }
            if index == 2 {
                BackspaceRepeatButton {
                    model.proxy?.deleteBackward()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func sideKey(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 44, height: 34)
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private func display(for key: String) -> String {
        (!symbolMode && shift) ? key.uppercased() : key
    }

    private func insert(_ key: String) {
        model.proxy?.insertText(display(for: key))
        if shift && !symbolMode {
            shift = false
        }
    }
}

/// 长按连续删除的退格键：短按删一个，长按 0.35s 后每 90ms 连删。
struct BackspaceRepeatButton: View {
    var action: () -> Void
    @State private var timer: Timer?

    var body: some View {
        Image(systemName: "delete.left")
            .font(.system(size: 16))
            .frame(width: 44, height: 34)
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.35)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onChanged { value in
                        if case .second(true, nil) = value {
                            startRepeating()
                        }
                    }
                    .onEnded { _ in
                        stopRepeating()
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    action()
                }
            )
            .onDisappear {
                stopRepeating()
            }
    }

    private func startRepeating() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { _ in
            action()
        }
    }

    private func stopRepeating() {
        timer?.invalidate()
        timer = nil
    }
}
