import SwiftUI
import TypeFreeCore

@main
struct TypeFreeApp: App {
    @StateObject private var store = SettingsRepository()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

/// 主 App 侧的设置仓库（与键盘扩展共享同一 App Group 数据）。
@MainActor
final class SettingsRepository: ObservableObject {
    let vault = ProviderVault()
    @Published var settings: TypeFreeSettings

    init() {
        settings = ProviderVault().loadSettings()
    }

    func reload() {
        settings = vault.loadSettings()
    }

    func save(_ newSettings: TypeFreeSettings) {
        settings = newSettings
        vault.saveSettings(newSettings)
    }

    func update(_ mutate: (inout TypeFreeSettings) -> Void) {
        var next = settings
        mutate(&next)
        save(next)
    }

    func saveCredentials(_ credentials: ProviderCredentials, for kind: ProviderKind) {
        vault.saveCredentials(credentials, for: kind)
        reload()
    }
}
