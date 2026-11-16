import XCTest
@testable import TypeFreeCore

final class MultipartBodyTests: XCTestCase {

    func testStructure() throws {
        var body = MultipartBody(boundary: "BOUNDARY123")
        body.addField(name: "model", value: "whisper-large-v3")
        body.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", fileData: Data([0x01, 0x02]))
        body.finalize()

        let text = String(decoding: body.data, as: UTF8.self)
        XCTAssertTrue(text.contains("--BOUNDARY123\r\n"))
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"model\""))
        XCTAssertTrue(text.contains("filename=\"audio.wav\""))
        XCTAssertTrue(text.contains("Content-Type: audio/wav"))
        XCTAssertTrue(text.hasSuffix("--BOUNDARY123--\r\n"))
        XCTAssertEqual(body.contentTypeHeader, "multipart/form-data; boundary=BOUNDARY123")
    }
}

final class PolishPromptTests: XCTestCase {

    let service = PolishService()

    func testDictatePromptMentionsFillerWords() {
        let request = PolishService.Request(intent: .dictate, rawText: "嗯明天下午三点不对四点开会")
        let system = service.systemPrompt(for: request)
        XCTAssertTrue(system.contains("口癖"))
        XCTAssertTrue(system.contains("改口"))
        XCTAssertTrue(system.contains("只输出"))
    }

    func testHelpWriteIncludesAttitude() {
        let attitude = AttitudeChip.defaults[1] // 婉拒
        let request = PolishService.Request(intent: .helpWrite, rawText: "周末出差", attitude: attitude)
        let user = service.userPrompt(for: request)
        XCTAssertTrue(user.contains("婉拒"))
        XCTAssertTrue(user.contains("周末出差"))
    }

    func testTranslateBilingualRouting() {
        let request = PolishService.Request(intent: .translate, rawText: "你好世界", translateTarget: .japanese)
        let user = service.userPrompt(for: request)
        XCTAssertTrue(user.contains("日文"))
        let system = service.systemPrompt(for: request)
        XCTAssertTrue(system.contains("翻译"))
    }

    func testStyleInjectedIntoSystem() {
        let style = StylePreset(name: "自定义", promptHint: "全部使用短句。")
        let request = PolishService.Request(intent: .dictate, rawText: "测试", style: style)
        XCTAssertTrue(service.systemPrompt(for: request).contains("全部使用短句。"))
    }

    func testTrimOutputStripsFences() {
        XCTAssertEqual(PolishService.trimOutput("```text\nhello\n```"), "hello")
        XCTAssertEqual(PolishService.trimOutput("  直接输出  "), "直接输出")
    }

    func testMessagesBuilt() {
        let request = PolishService.Request(intent: .ask, rawText: "今天天气如何？")
        let messages = service.buildMessages(for: request)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertEqual(messages[1].content, "今天天气如何？")
    }
}
