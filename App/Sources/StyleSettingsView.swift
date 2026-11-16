import SwiftUI
import TypeFreeCore

/// 「文风」页：文风预设管理 + 帮写态度芯片管理。
struct StyleSettingsView: View {
    @EnvironmentObject private var store: SettingsRepository
    @State private var newStyleName = ""
    @State private var newStyleHint = ""

    var body: some View {
        NavigationStack {
            List {
                Section("当前文风") {
                    ForEach(store.settings.styles) { style in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(style.name).font(.system(size: 15, weight: .medium))
                                    if style.isBuiltin {
                                        Text("内置")
                                            .font(.system(size: 10))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(style.promptHint)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if store.settings.activeStyle()?.id == style.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button("选用") {
                                    store.update { $0.activeStyleID = style.id }
                                }
                                .font(.system(size: 12, weight: .medium))
                                .buttonStyle(.bordered)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !style.isBuiltin {
                                Button(role: .destructive) {
                                    store.update { settings in
                                        settings.styles.removeAll { $0.id == style.id }
                                    }
                                } label: { Label("删除", systemImage: "trash") }
                            }
                        }
                    }
                }

                Section("新增自定义文风") {
                    TextField("名称（如：催办强硬）", text: $newStyleName)
                    TextField("风格指令（如：短句、直给、带截止时间）", text: $newStyleHint)
                    Button {
                        let name = newStyleName.trimmingCharacters(in: .whitespaces)
                        let hint = newStyleHint.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty, !hint.isEmpty else { return }
                        store.update {
                            $0.styles.append(StylePreset(name: name, promptHint: hint))
                        }
                        newStyleName = ""
                        newStyleHint = ""
                    } label: {
                        Label("添加文风", systemImage: "plus")
                    }
                    .disabled(newStyleName.trimmingCharacters(in: .whitespaces).isEmpty
                              || newStyleHint.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("✍️ 帮写态度芯片（键盘上滑出）") {
                    ForEach(store.settings.attitudes) { chip in
                        Text("\(chip.emoji) \(chip.label) — \(chip.promptHint)")
                            .font(.system(size: 13))
                    }
                    Text("v0.2 将支持在手机上直接增删改态度芯片；当前可在键盘长按查看默认 6 枚。")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("文风")
        }
    }
}
