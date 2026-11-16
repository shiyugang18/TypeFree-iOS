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

    /// 打开流式响应（SSE），逐块产出文本分片。
    public func streamBytes(
        url: URL,
        headers: [String: String],
        body: Data
    ) -> AsyncThrowingStream<Data, Error> {
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
                    for try await byte in bytes {
                        continuation.yield(Data([byte]))
                    }
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
