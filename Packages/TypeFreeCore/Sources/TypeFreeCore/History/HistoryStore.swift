import Foundation

/// 历史记录存储（App Group 共享容器内 JSON 行文件，按留存天数自动清理）。
public final class HistoryStore: @unchecked Sendable {

    let vault: ProviderVault
    let fileName = "history.json"

    public init(vault: ProviderVault) {
        self.vault = vault
    }

    /// 实际的共享容器目录（ FileManager containerURL）。
    var sharedDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ProviderVault.appGroupID)
    }

    var historyURL: URL? {
        sharedDirectory?.appendingPathComponent(fileName)
    }

    public func loadAll() -> [HistoryItem] {
        guard let url = historyURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
    }

    public func append(_ item: HistoryItem) {
        let settings = vault.loadSettings()
        guard !settings.incognito else { return }
        guard settings.historyDays != 0 else { return }
        var items = loadAll()
        items.insert(item, at: 0)
        items = enforceRetention(items, days: settings.historyDays)
        persist(items)
    }

    public func removeAll() {
        persist([])
    }

    public func remove(ids: Set<UUID>) {
        persist(loadAll().filter { !ids.contains($0.id) })
    }

    func enforceRetention(_ items: [HistoryItem], days: Int) -> [HistoryItem] {
        guard days > 0 else { return items } // -1 = 永久
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return items.filter { $0.date >= cutoff }
    }

    func persist(_ items: [HistoryItem]) {
        guard let url = historyURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            // 存储失败静默降级：历史记录是非关键路径。
        }
    }
}
