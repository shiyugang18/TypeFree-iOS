import Foundation

/// SSE (Server-Sent Events) 增量解析器。
/// 逐块喂入原始文本，产出完整的 data 事件。
public struct SSEParser {
    private var buffer = ""
    private var currentData = ""

    public init() {}

    /// 喂入一个网络分片，返回本次解析出的事件 data 载荷数组。
    public mutating func feed(_ chunk: String) -> [String] {
        buffer += chunk
        var events: [String] = []

        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)

            if line.isEmpty {
                // 空行 = 事件边界。
                if !currentData.isEmpty {
                    events.append(currentData)
                    currentData = ""
                }
            } else if line.hasPrefix("data:") {
                let payload = String(line.dropFirst(5))
                let trimmed = payload.hasPrefix(" ") ? String(payload.dropFirst()) : payload
                if !currentData.isEmpty {
                    currentData += "\n"
                }
                currentData += trimmed
            }
            // 其他字段（event:/id:/retry:）v0.1 忽略。
        }
        return events
    }

    /// 流结束时冲刷残余缓冲。
    public mutating func flush() -> [String] {
        var events: [String] = []
        if !buffer.isEmpty {
            events.append(contentsOf: feed("\n"))
        }
        if !currentData.isEmpty {
            events.append(currentData)
            currentData = ""
        }
        return events
    }
}
