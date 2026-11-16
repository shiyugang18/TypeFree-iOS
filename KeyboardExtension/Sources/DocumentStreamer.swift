import UIKit

/// 键盘内流式写入状态机（对齐上游 `StreamingComposer` 的草稿→定稿原地替换语义）。
/// iOS 的 `UITextDocumentProxy` 没有组合态 API，用「删回草稿再插新稿」模拟：
/// 识别出原文 → 先插入草稿；润色完成 → 原地替换为定稿。
final class DocumentStreamer {

    private(set) var insertedDraft: String = ""
    /// 最近一次最终上屏文本（供「↶ 撤回」使用）。
    private(set) var lastFinal: String = ""

    /// 插入/替换当前草稿。
    func insertDraft(_ text: String, proxy: UITextDocumentProxy) {
        removeCurrentDraft(proxy: proxy)
        guard !text.isEmpty else {
            insertedDraft = ""
            return
        }
        proxy.insertText(text)
        insertedDraft = text
    }

    /// 将草稿替换为最终定稿，并结束本轮组合。
    func finalize(_ finalText: String, proxy: UITextDocumentProxy) {
        removeCurrentDraft(proxy: proxy)
        guard !finalText.isEmpty else {
            reset()
            return
        }
        proxy.insertText(finalText)
        lastFinal = finalText
        insertedDraft = ""
    }

    /// 直接插入定稿（无草稿路径，如 ⚡ 直接生成）。
    func commitDirect(_ text: String, proxy: UITextDocumentProxy) {
        guard !text.isEmpty else { return }
        proxy.insertText(text)
        lastFinal = text
    }

    /// 撤回最近一次最终上屏。
    func undoFinal(proxy: UITextDocumentProxy) {
        guard !lastFinal.isEmpty else { return }
        proxy.deleteBackward(times: lastFinal.count)
        lastFinal = ""
    }

    func reset() {
        insertedDraft = ""
    }

    private func removeCurrentDraft(proxy: UITextDocumentProxy) {
        if !insertedDraft.isEmpty {
            proxy.deleteBackward(times: insertedDraft.count)
        }
        insertedDraft = ""
    }
}

extension UITextDocumentProxy {
    /// 按字符个数连续删除。
    func deleteBackward(times: Int) {
        guard times > 0 else { return }
        for _ in 0..<times {
            deleteBackward()
        }
    }
}
