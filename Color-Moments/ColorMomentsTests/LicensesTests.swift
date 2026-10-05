import XCTest
@testable import ColorMoments

final class LicensesTests: XCTestCase {
    func testNoticeShipsInTheAppWithEveryLicense() throws {
        let text = try XCTUnwrap(LicensesSheet.text(), "NOTICE 가 앱 번들에 없다")
        for needle in ["Copyright (c) Microsoft Corporation", "CC BY-SA 2.0 KR", "https://creativecommons.org/licenses/by-sa/2.0/kr/",
                       "일부 뜻풀이를 새로 썼습니다", "SIL Open Font License", "NHN Corporation",
                       "The Gowun Dodum Project Authors", "IBM Corp."] {
            XCTAssertTrue(text.contains(needle), needle)
        }
    }
}
