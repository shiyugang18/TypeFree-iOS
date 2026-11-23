import Foundation

/// 一阶段听音转写引擎协议（REST 整包上传形态）。
public protocol STTEngine: Sendable {
    /// 将 WAV 音频上传并返回识别出的原始文本。
    func transcribe(wavData: Data) async throws -> String
}

public enum STTFactory {
    /// 根据工作流配置构造引擎。
    public static func make(provider: ProviderKind, model: String, credentials: ProviderCredentials) throws -> STTEngine {
        let resolver = EndpointResolver(kind: provider, role: .stt, credentials: credentials)
        let client = HTTPClient()
        if resolver.usesStrictFileOnlyASR {
            return DeepSeekASREngine(resolver: resolver, client: client)
        }
        return OpenAICompatSTTEngine(resolver: resolver, client: client, model: model)
    }
}

/// DeepSeek 官方语音识别：POST /v1/tools/asr。
/// 协议级严格适配（对齐上游 v3.5.1）：仅传 `file` 字段，
/// 不传 model / language / prompt / response_format，由服务端自动识别语种。
public struct DeepSeekASREngine: STTEngine {
    let resolver: EndpointResolver
    let client: HTTPClient

    public func transcribe(wavData: Data) async throws -> String {
        let url = try resolver.sttTranscriptionURL()
        let headers = try resolver.authHeaders()

        var multipart = MultipartBody()
        multipart.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", fileData: wavData)
        multipart.finalize()

        var requestHeaders = headers
        requestHeaders["Content-Type"] = multipart.contentTypeHeader

        let responseData = try await client.postRaw(
            url: url,
            headers: requestHeaders,
            body: multipart.data,
            timeout: 90
        )
        return try Self.extractText(from: responseData)
    }

    /// 宽容解析：尝试多种响应结构（text / data.text / result.text / segments 拼接）。
    static func extractText(from data: Data) throws -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 有些实现直接返回纯文本。但网关把未知路径回落到前端页面时同样回 200 + HTML，
            // 那不是转写结果，不能当成原文送进润色。
            if let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty, !text.hasPrefix("<") {
                return text
            }
            throw STTError.badResponse
        }
        if let text = obj["text"] as? String { return text }
        if let data = obj["data"] as? [String: Any], let text = data["text"] as? String { return text }
        if let result = obj["result"] as? [String: Any], let text = result["text"] as? String { return text }
        if let segments = obj["segments"] as? [[String: Any]] {
            let joined = segments.compactMap { $0["text"] as? String }.joined(separator: "")
            if !joined.isEmpty { return joined }
        }
        if let errMessage = obj["message"] as? String {
            throw STTError.providerMessage(errMessage)
        }
        throw STTError.badResponse
    }
}

/// OpenAI 兼容转写端点：POST {base}/audio/transcriptions。
/// 覆盖硅基流动 SenseVoiceSmall、Groq whisper、本地 whisper.cpp 等。
public struct OpenAICompatSTTEngine: STTEngine {
    let resolver: EndpointResolver
    let client: HTTPClient
    let model: String

    public func transcribe(wavData: Data) async throws -> String {
        let url = try resolver.sttTranscriptionURL()
        let headers = try resolver.authHeaders()

        var multipart = MultipartBody()
        if !model.isEmpty {
            multipart.addField(name: "model", value: model)
        }
        multipart.addField(name: "response_format", value: "json")
        multipart.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", fileData: wavData)
        multipart.finalize()

        var requestHeaders = headers
        requestHeaders["Content-Type"] = multipart.contentTypeHeader

        let responseData = try await client.postRaw(
            url: url,
            headers: requestHeaders,
            body: multipart.data,
            timeout: 90
        )
        return try DeepSeekASREngine.extractText(from: responseData)
    }
}

public enum STTError: Error, LocalizedError {
    case badResponse
    case providerMessage(String)

    public var errorDescription: String? {
        switch self {
        case .badResponse:
            return "语音识别服务返回了无法解析的响应（请确认该服务商的地址支持 /audio/transcriptions 语音转写接口）"
        case .providerMessage(let message):
            return "语音识别服务报错：\(message)"
        }
    }
}
