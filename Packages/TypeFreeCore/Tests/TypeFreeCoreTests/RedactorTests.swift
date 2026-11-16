import XCTest
@testable import TypeFreeCore

final class RedactorTests: XCTestCase {

    func testRedactPhone() {
        let redactor = Redactor(enabled: true)
        let result = redactor.redact("我的手机号是13812345678，记得联系我")
        XCTAssertFalse(result.sanitized.contains("13812345678"))
        XCTAssertTrue(result.sanitized.contains("[手机号_1]"))
        XCTAssertEqual(result.replacements["[手机号_1]"], "13812345678")
    }

    func testRedactIDCard() {
        let redactor = Redactor(enabled: true)
        let result = redactor.redact("身份证号110101199003077578")
        XCTAssertTrue(result.sanitized.contains("[身份证_1]"))
        XCTAssertEqual(result.replacements["[身份证_1]"], "110101199003077578")
    }

    func testRedactBankCard() {
        let redactor = Redactor(enabled: true)
        let result = redactBankCardHelper("卡号6222021234567890123")
        XCTAssertTrue(result.sanitized.contains("[银行卡_"))
    }

    private func redactBankCardHelper(_ text: String) -> Redactor.Result {
        Redactor(enabled: true).redact(text)
    }

    func testRedactWeChat() {
        let redactor = Redactor(enabled: true)
        let result = redactor.redact("加我微信：hello_world_99")
        XCTAssertTrue(result.sanitized.contains("[微信号_1]"))
        XCTAssertEqual(result.replacements["[微信号_1]"], "微信：hello_world_99")
    }

    func testRedactMultiplePhones() {
        let redactor = Redactor(enabled: true)
        let result = redactor.redact("爸爸15912345678妈妈15987654321")
        XCTAssertTrue(result.sanitized.contains("[手机号_1]"))
        XCTAssertTrue(result.sanitized.contains("[手机号_2]"))
        XCTAssertEqual(result.replacements.count, 2)
    }

    func testRestoreRoundtrip() {
        let redactor = Redactor(enabled: true)
        let original = "发到13812345678，身份证110101199003077578"
        let redacted = redactor.redact(original)
        let restored = Redactor.restore(redacted.sanitized, replacements: redacted.replacements)
        XCTAssertEqual(restored, original)
    }

    func testDisabledRedactorKeepsText() {
        let redactor = Redactor(enabled: false)
        let text = "手机13812345678"
        let result = redactor.redact(text)
        XCTAssertEqual(result.sanitized, text)
        XCTAssertTrue(result.replacements.isEmpty)
    }

    func testShortNumbersUntouched() {
        let redactor = Redactor(enabled: true)
        let result = redactor.redact("取件码425666，订单号12345")
        XCTAssertEqual(result.sanitized, "取件码425666，订单号12345")
    }
}
