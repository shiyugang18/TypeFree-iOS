import Foundation

/// 极简 URLSession 异步封装。
public struct HTTPClient: Sendable {
    public var session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 120
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }
    }

    public enum HTTPError: Error, LocalizedError {
        case badStatus(Int, String)

        public var errorDescription: String? {
            switch self {
            case .badStatus(let code, let body):
                let snippet = body.prefix(300)
                return "HTTP \(code)：\(snippet)"
            }
        }
    }

    /// POST JSON 并解析 JSON 响应。
    public func postJSON<Body: Encodable, Response: Decodable>(
        url: URL,
        headers: [String: String],
        body: Body,
        responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw HTTPError.badStatus(status, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// POST 原始 Data（multipart），返回原始响应 Data。
    public func postRaw(
        url: URL,
        headers: [String: String],
        body: Data,
        timeout: TimeInterval = 60
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw HTTPError.badStatus(status, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    /// 打开流式响应（SSE），逐行产出文本（每行以换行符结尾，流末尾的残行除外）。
    /// 必须攒成整行再交付：bytes 是逐字节迭代的，而中文等多字节 UTF-8 字符被拆成
    /// 单字节后无法解码（String(data:encoding:) 返回 nil），会被上层当作无效分片静默丢弃。
    public func streamLines(
        url: URL,
        headers: [String: String],
        body: Data
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 90
                for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.httpBody = body

                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        // 流式失败：读出错误体。
                        var errData = Data()
                        for try await byte in bytes { errData.append(byte) }
                        throw HTTPError.badStatus(status, String(data: errData, encoding: .utf8) ?? "")
                    }
                    var lines = LineAssembler()
                    for try await byte in bytes {
                        if let line = lines.feed(byte) { continuation.yield(line) }
                    }
                    if let tail = lines.flush() { continuation.yield(tail) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

/// 把逐字节到达的网络分片攒成整行文本。
public struct LineAssembler: Sendable {
    private var buffer = Data()

    public init() {}

    /// 喂入一个字节；遇到换行符时返回已凑齐的整行（含换行符）。
    public mutating func feed(_ byte: UInt8) -> String? {
        guard byte == 0x0A else {
            buffer.append(byte)
            return nil
        }
        let line = String(data: buffer, encoding: .utf8).map { $0 + "\n" }
        buffer.removeAll(keepingCapacity: true)
        return line
    }

    /// 流结束时取出残余内容（没有换行结尾的最后一行）。
    public mutating func flush() -> String? {
        guard !buffer.isEmpty else { return nil }
        let tail = String(data: buffer, encoding: .utf8)
        buffer.removeAll()
        return tail
    }
}
