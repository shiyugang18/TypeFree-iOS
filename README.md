# TypeFree iOS — AI 语音听写键盘

[![License: GPL v3.0](https://img.shields.io/badge/License-GPL_v3.0-blue.svg)](LICENSE)
[![iOS 16+](https://img.shields.io/badge/iOS-16.0%2B-10B981)]()
[![Swift](https://img.shields.io/badge/Swift-5.9-7F52FF)]()

TypeFree 的 **iOS 原生移植版**（纯 Swift + SwiftUI），灵感与功能设计来自上游
[TypeFree（Android 版）](https://github.com/dengxuezhao/TypeFree)（GPL-3.0）。

🎙️ **按住说话 → 识别 → AI 润色 → 上屏**，全面践行 **BYOK（自带 Key）** 与隐私优先：
零中心服务器、无埋点、无广告 SDK，端侧敏感信息脱敏后再上云。

---

## ✨ v0.1 功能清单

- **键盘扩展（TypeFree 语音键盘）**
  - 🎙️ 按住说话、松手上屏；识别原文先以「草稿」插入，润色完成后**原地替换**（对齐上游 StreamingComposer 语义）
  - ✍️ 帮写：6 枚默认平视态度芯片（行/好的、婉拒、追问、接梗、硬气回怼、正式得体），选中后按住麦克风说细节，或 **⚡ 免开口直接生成**
  - 🎨 文风胶囊菜单（自然精炼/商务得体/极简要点/俏皮社交/学术严谨 + 自定义）
  - ↶ 撤回、🫥 无痕模式即时生效、60 秒超长录音自动收尾
  - 内置极简 QWERTY + 数字符号层，可独立打字；🌐 一键切系统键盘
- **一阶段听音（STT，REST 整包）**
  - DeepSeek 官方 ASR（`POST /v1/tools/asr`，严格 file-only 协议）→ **单 Key 全链路闭环**
  - 硅基流动 `FunAudioLLM/SenseVoiceSmall`（免费听音）
  - Groq `whisper-large-v3`、任意 OpenAI 兼容端点 / 本地 whisper.cpp
- **二阶段大脑（LLM，SSE 流式）**
  - DeepSeek / 火山方舟豆包 / 阿里百炼兼容模式 / 硅基流动 / Gemini / Groq / 本地 Ollama / 自定义网关
  - 五大意图：口述净写（去口癖 / 改口纠正 / 断句）· 帮写 · 快译 · 改写 · 问AI（试场内可用）
  - ⚡ 润色模型首字延迟测速
- **隐私**
  - 🛡️ 端侧正则脱敏：手机号 / 身份证 / 银行卡 / 微信号 → `[手机号_1]` 占位符上云，本地无损还原
  - 🫥 无痕模式、历史留存周期（0/3/7/30 天/永久）
  - ⚠️ 银行 / 密码框场景熔断与剪贴板胶囊将在后续版本补齐

## 🚫 与 Android 版的能力差异（平台限制）

| 能力 | Android 版 | iOS 版现状 |
|---|---|---|
| 全局悬浮胶囊 | ✅ | ❌ iOS 禁止跨 App 悬浮窗 |
| 读屏截屏 AI 帮回（Jev 军师） | ✅ 无障碍服务 | ❌ 平台不允许读其他 App |
| 实时流式 ASR（豆包 / 百炼 / Gemini Live WSS） | ✅ | 🗓️ Phase 2 |
| librime 输入方案（雾凇 / 小鹤） | ✅ | 🗓️ Phase 3（26 键先行） |
| 智能剪贴板 2.0 / 大爆炸拆词 | ✅ | 🗓️ Phase 2 |

## 📦 构建与安装

### 方式 A：Mac 本地构建（推荐，可真机安装）

```bash
git clone <本仓库> TypeFree-iOS
cd TypeFree-iOS

# 生成 Xcode 工程（需要 xcodegen：brew install xcodegen）
xcodegen generate

open TypeFree.xcodeproj
```

在 Xcode 中：
1. 选中 `TypeFree` target → Signing & Capabilities → 选择你的 **Personal Team**（免费 Apple ID 即可）
2. 两个 target（App + Keyboard）都要选同一个 Team，并确认 **App Groups** `group.com.typefree.ios.shared` 已勾选生效
3. 插上 iPhone，选择 `TypeFree` scheme → Run

### 方式 B：GitHub Actions 云构建（无 Mac 也能持续验证）

仓库自带 `.github/workflows/ci.yml`：每次 push 自动在 macOS 云上跑

- `swift test`（TypeFreeCore 单元测试）
- 模拟器构建 + App Store 仓库校验构建（`CODE_SIGNING_ALLOWED=NO`）

> 注意：云构建产物**未签名**，不能直接装到真机；真机安装请在 Mac 上用个人证书签名。

### 三步激活键盘（装好后）

1. 设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → **TypeFree 语音键盘**
2. 点进键盘条目 → 打开 **「允许完全访问」**（联网 + 麦克风必需）
3. 主 App「API 配置」页填 Key（推荐下面两种方案）

## 🔌 推荐 API 配置（与上游指南对齐）

| 方案 | 听音（一阶段） | 大脑（二阶段） | 说明 |
|---|---|---|---|
| **DeepSeek 单 Key 闭环** | DeepSeek ASR | `deepseek-chat` | 一把 Key 通吃，最省心 |
| **极致性价比** | 硅基 `SenseVoiceSmall`（免费） | `deepseek-chat` | 听音 0 成本 |
| **全离线** | 本地 whisper.cpp | 本地 Ollama | 内网可用，零 API 费用 |
| **海外免翻** | Groq whisper-large-v3 | Gemini / GPT 系 | 直连 |

在服务商详情页点 **「🚀 一键设为当前主力方案」** 或 **「🧠 仅设为文本大脑」**（保留已配好的听音通道）。

## 🔒 隐私与安全说明

- 语音 / 文本只发送给你自己配置的 API 端点，本项目无任何自有服务端
- API Key 当前版本以 **XOR 混淆 + Base64** 形式存于 App Group 共享容器（主 App 与键盘共享配置所需）；
  **Phase 2 升级为 Keychain 共享访问组加密存储**（届时无缝迁移）
- 键盘扩展只有在你打开「允许完全访问」后才具备联网与麦克风能力，否则语音功能不可用

## 🗺️ Roadmap

- **Phase 2**：豆包 SeedASR / 百炼 DashScope / Gemini Live WebSocket 实时流式（边说边上屏）· Keychain 加密凭证 · 按 App 绑定文风 · 智能剪贴板
- **Phase 3**：内置 26 键完整键盘 · librime（雾凇拼音 / 小鹤双拼）iOS 移植 · macOS 菜单栏版（同一套 TypeFreeCore）

## 📄 许可证

本项目基于 **GPL-3.0** 开源，是 TypeFree（Android）的移植/衍生作品，同样以 GPL-3.0 释出。
欢迎 Issue 与 PR！

- 上游项目：https://github.com/dengxuezhao/TypeFree
