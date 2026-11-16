import AVFoundation
import Foundation
import TypeFreeCore

/// 麦克风采集器：AVAudioEngine 输入 tap → AVAudioConverter 重采样 →
/// 16kHz 单声道 Int16 PCM → WAV（对齐上游音频约定）。
/// 主 App 听写试场与键盘扩展共用。
final class AudioRecorder {

    enum RecorderError: LocalizedError {
        case micUnavailable
        case conversionFailed(String)

        var errorDescription: String? {
            switch self {
            case .micUnavailable: return "无法访问麦克风"
            case .conversionFailed(let detail): return "音频重采样失败：\(detail)"
            }
        }
    }

    private let engine = AVAudioEngine()
    private var samples: [Int16] = []
    private let samplesLock = NSLock()
    private var isRunning = false

    /// 录音电平回调（0~1），用于 UI 波动条。
    var levelHandler: ((Float) -> Void)?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() throws {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: [])

        samplesLock.lock()
        samples = []
        samplesLock.unlock()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            throw RecorderError.micUnavailable
        }
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else {
            throw RecorderError.conversionFailed("目标格式创建失败")
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: target) else {
            throw RecorderError.conversionFailed("转换器创建失败")
        }

        input.removeTap(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.consume(buffer: buffer, converter: converter)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    /// 停止录音并返回整段 WAV；若无可识别音频返回 nil。
    func stopAndBuildWAV() -> Data? {
        guard isRunning else { return nil }
        teardown()
        samplesLock.lock()
        let all = samples
        samples = []
        samplesLock.unlock()
        guard !all.isEmpty else { return nil }
        return WavEncoder.encode(samples: all, sampleRate: 16000)
    }

    /// 丢弃本次录音。
    func discard() {
        guard isRunning else { return }
        teardown()
        samplesLock.lock()
        samples = []
        samplesLock.unlock()
    }

    // MARK: - Private

    private func teardown() {
        engine.inputNode.removeTap(forBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        isRunning = false
    }

    private func consume(buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        let ratio = 16000.0 / max(buffer.format.sampleRate, 1)
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio * 1.5) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return }

        var fedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: out, error: &conversionError) { _, outStatus in
            if fedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            fedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status == .haveData,
              let channel = out.int16ChannelData?[0],
              conversionError == nil else { return }

        let count = Int(out.frameLength)
        guard count > 0 else { return }
        var chunk = [Int16](repeating: 0, count: count)
        var energy: Int64 = 0
        for index in 0..<count {
            let sample = channel[index]
            chunk[index] = sample
            energy += Int64(abs(Int32(sample)))
        }

        samplesLock.lock()
        samples.append(contentsOf: chunk)
        samplesLock.unlock()

        // RMS 电平（做 3 倍增益便于肉眼观察）。
        let rms = sqrt(Double(energy) / Double(count)) / 32768.0
        let level = Float(min(rms * 3.0, 1.0))
        DispatchQueue.main.async { [weak self] in
            self?.levelHandler?(level)
        }
    }
}
