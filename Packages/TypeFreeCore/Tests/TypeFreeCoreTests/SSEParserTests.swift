import XCTest
@testable import TypeFreeCore

final class SSEParserTests: XCTestCase {

    func testSingleEvent() {
        var parser = SSEParser()
        let events = parser.feed("data: {\"a\":1}\n\n")
        XCTAssertEqual(events, ["{\"a\":1}"])
    }

    func testChunkedAcrossFeeds() {
        var parser = SSEParser()
        XCTAssertTrue(parser.feed("data: hel").isEmpty) // 未遇到空行，事件未完成
        let events = parser.feed("lo\n\n")
        XCTAssertEqual(events, ["hello"])
    }

    func testMultipleEvents() {
        var parser = SSEParser()
        let events = parser.feed("data: one\n\ndata: two\n\ndata: [DONE]\n\n")
        XCTAssertEqual(events, ["one", "two", "[DONE]"])
    }

    func testNoSpaceAfterColon() {
        var parser = SSEParser()
        let events = parser.feed("data:nospace\n\n")
        XCTAssertEqual(events, ["nospace"])
    }

    func testFlushTrailing() {
        var parser = SSEParser()
        _ = parser.feed("data: tail")
        let events = parser.flush()
        XCTAssertEqual(events, ["tail"])
    }

    func testIgnoreOtherFields() {
        var parser = SSEParser()
        let events = parser.feed("event: add\nid: 1\ndata: payload\n\n")
        XCTAssertEqual(events, ["payload"])
    }
}

final class LineAssemblerTests: XCTestCase {

    /// 回归：流式分片逐字节到达时，中文（多字节 UTF-8）曾因单字节解码失败被整段丢弃。
    func testChineseSurvivesByteByByteFeed() {
        let payload = "data: {\"delta\":{\"content\":\"明天4点开会。\"}}\n\n"
        var assembler = LineAssembler()
        var parser = SSEParser()
        var events: [String] = []

        for byte in Array(payload.utf8) {
            if let line = assembler.feed(byte) {
                events += parser.feed(line)
            }
        }
        events += parser.flush()

        XCTAssertEqual(events, ["{\"delta\":{\"content\":\"明天4点开会。\"}}"])
    }

    func testFlushTrailingLineWithoutNewline() {
        var assembler = LineAssembler()
        for byte in Array("data: 尾".utf8) {
            XCTAssertNil(assembler.feed(byte))
        }
        XCTAssertEqual(assembler.flush(), "data: 尾")
        XCTAssertNil(assembler.flush())
    }
}
