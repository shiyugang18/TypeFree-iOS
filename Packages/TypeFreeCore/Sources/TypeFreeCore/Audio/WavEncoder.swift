import Foundation

/// 16kHz 单声道 16-bit PCM WAV 编码器。
/// 上游约定：DeepSeek ASR 与通用转写端点均上传 16kHz 单声道 WAV。
public enum WavEncoder {

    /// 将原始 Int16 PCM 样本编码为完整 WAV 文件数据。
    /// - Parameters:
    ///   - samples: 交错后的单声道样本。
    ///   - sampleRate: 采样率（默认 16000）。
    public static func encode(samples: [Int16], sampleRate: Int = 16000) -> Data {
        let sampleCount = samples.count
        let byteCount = sampleCount * 2

        var data = Data()
        data.reserveCapacity(44 + byteCount)

        // RIFF header
        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(&data, UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVE".utf8))

        // fmt chunk
        data.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(&data, 16)                    // fmt chunk size
        appendUInt16(&data, 1)                     // PCM
        appendUInt16(&data, 1)                     // channels
        appendUInt32(&data, UInt32(sampleRate))    // sample rate
        appendUInt32(&data, UInt32(sampleRate * 2))// byte rate = rate * channels * 2
        appendUInt16(&data, 2)                     // block align
        appendUInt16(&data, 16)                    // bits per sample

        // data chunk
        data.append(contentsOf: Array("data".utf8))
        appendUInt32(&data, UInt32(byteCount))
        for sample in samples {
            appendUInt16(&data, UInt16(bitPattern: sample))
        }
        return data
    }

    /// 校验 WAV 头信息，测试用。
    public static func validateHeader(_ data: Data) -> (sampleRate: Int, channels: Int, dataBytes: Int)? {
        guard data.count >= 44 else { return nil }
        let bytes = [UInt8](data.prefix(44))
        guard String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF",
              String(bytes: bytes[8..<12], encoding: .ascii) == "WAVE",
              String(bytes: bytes[12..<16], encoding: .ascii) == "fmt " else { return nil }
        let channels = Int(bytes[22]) | (Int(bytes[23]) << 8)
        let sampleRate = Int(bytes[24])
            | (Int(bytes[25]) << 8)
            | (Int(bytes[26]) << 16)
            | (Int(bytes[27]) << 24)
        let dataBytes = Int(bytes[40])
            | (Int(bytes[41]) << 8)
            | (Int(bytes[42]) << 16)
            | (Int(bytes[43]) << 24)
        return (sampleRate, channels, dataBytes)
    }

    static func appendUInt16(_ data: inout Data, _ value: UInt16) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    static func appendUInt32(_ data: inout Data, _ value: UInt32) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
