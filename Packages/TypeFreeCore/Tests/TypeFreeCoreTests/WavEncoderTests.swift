import XCTest
@testable import TypeFreeCore

final class WavEncoderTests: XCTestCase {

    func testEncodeHeader() throws {
        let samples: [Int16] = [0, 1000, -1000, 32767, -32768]
        let wav = WavEncoder.encode(samples: samples, sampleRate: 16000)

        XCTAssertEqual(wav.count, 44 + samples.count * 2)
        let header = try XCTUnwrap(WavEncoder.validateHeader(wav))
        XCTAssertEqual(header.sampleRate, 16000)
        XCTAssertEqual(header.channels, 1)
        XCTAssertEqual(header.dataBytes, samples.count * 2)
    }

    func testSampleBytesLittleEndian() throws {
        let wav = WavEncoder.encode(samples: [0x1234], sampleRate: 8000)
        let bytes = [UInt8](wav)
        // data 段第一个样本：0x34 0x12（小端）
        XCTAssertEqual(bytes[44], 0x34)
        XCTAssertEqual(bytes[45], 0x12)
    }

    func testEmptySamples() {
        let wav = WavEncoder.encode(samples: [], sampleRate: 16000)
        XCTAssertEqual(wav.count, 44)
        let header = WavEncoder.validateHeader(wav)
        XCTAssertEqual(header?.dataBytes, 0)
    }
}
