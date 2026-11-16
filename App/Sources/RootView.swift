import SwiftUI
import UIKit

struct RootView: View {
    var body: some View {
        TabView {
            OnboardingHomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
            APIConfigView()
                .tabItem { Label("API 配置", systemImage: "key.horizontal.fill") }
            StyleSettingsView()
                .tabItem { Label("文风", systemImage: "paintbrush.pointed.fill") }
            PlaygroundView()
                .tabItem { Label("听写试场", systemImage: "waveform.badge.mic") }
            HistoryView()
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
        }
    }
}

// MARK: - 首页引导

struct OnboardingHomeView: View {
    @EnvironmentObject private var store: SettingsRepository

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    activationCard
                    providerStatusCard
                    privacyCard
                }
                .padding(16)
            }
            .navigationTitle("TypeFree")
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🎙️ TypeFree iOS")
                .font(.system(size: 28, weight: .bold))
            Text("AI 语音听写键盘 · BYOK 自带 Key · 端侧脱敏 · 零中心服务器")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var activationCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("三步激活键盘")
                    .font(.system(size: 16, weight: .semibold))

                stepRow(number: 1, title: "添加键盘",
                        detail: "设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 选「TypeFree 语音键盘」")
                stepRow(number: 2, title: "允许完全访问",
                        detail: "添加后点进「TypeFree 语音键盘」→ 打开「允许完全访问」（联网与麦克风必需）")
                stepRow(number: 3, title: "配置 API Key",
                        detail: "到「API 配置」页填入 DeepSeek / 硅基流动等 Key，推荐一键预设")

                HStack {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("打开系统设置", systemImage: "gear")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func stepRow(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var providerStatusCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("当前方案")
                    .font(.system(size: 16, weight: .semibold))
                let workflow = store.settings.workflow
                row("👂 听音引擎", workflow.sttProvider.displayName, workflow.sttModel)
                row("🧠 润色引擎", workflow.polishEnabled ? workflow.llmProvider.displayName : "已关闭（识别直出）", workflow.llmModel)
                row("🛡️ 端侧脱敏", store.settings.redactionEnabled ? "已开启" : "已关闭", nil)
                row("🫥 无痕模式", store.settings.incognito ? "已开启" : "关闭", nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func row(_ title: String, _ value: String, _ sub: String?) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            VStack(alignment: .trailing) {
                Text(value).font(.system(size: 13, weight: .medium))
                if let sub, !sub.isEmpty {
                    Text(sub).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var privacyCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("隐私承诺")
                    .font(.system(size: 16, weight: .semibold))
                Text("TypeFree 不运营任何数据收集服务器，无埋点、无广告 SDK、无追踪器。你的语音与文本只发送给你自己配置的 API 端点；手机号 / 身份证 / 银行卡等敏感信息在端侧替换为占位符后再上云，并在本地无损还原。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }
}
