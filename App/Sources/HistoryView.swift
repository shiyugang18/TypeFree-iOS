import SwiftUI
import TypeFreeCore

/// 「历史」页：听写与帮写记录（受留存天数与无痕模式控制）。
struct HistoryView: View {
    @EnvironmentObject private var store: SettingsRepository
    @State private var items: [HistoryItem] = []
    @State private var selection = Set<UUID>()

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("暂无历史")
                            .font(.system(size: 17, weight: .semibold))
                        Text("键盘与听写试场的记录会出现在这里。\n开启无痕模式时不会记录任何内容。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    list
                }
            }
            .navigationTitle("历史")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        HistoryStore(vault: store.vault).removeAll()
                        reload()
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    .disabled(items.isEmpty)
                }
            }
            .onAppear(perform: reload)
            .refreshable { reload() }
        }
    }

    private var list: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.intent)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    Text(item.providerSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Text(item.finalText)
                    .font(.system(size: 14))
                    .lineLimit(4)
                if item.rawText != item.finalText, !item.rawText.isEmpty {
                    Text("原稿：\(item.rawText)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 2)
            .swipeActions {
                Button(role: .destructive) {
                    HistoryStore(vault: store.vault).remove(ids: [item.id])
                    reload()
                } label: { Label("删除", systemImage: "trash") }
            }
        }
    }

    private func reload() {
        store.reload()
        items = HistoryStore(vault: store.vault).loadAll()
    }
}
