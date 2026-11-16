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
