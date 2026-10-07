import XCTest
@testable import ColorMoments

final class UpdateCheckTests: XCTestCase {

    private final class Probe {
        var calls: [URL] = []
        var reply: Result<Data, Error> = .success(Data())
        var now = Date(timeIntervalSince1970: 1_791_000_000)
    }

    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        suite = "UpdateCheckTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func check(_ probe: Probe) -> UpdateCheck {
        UpdateCheck(fetch: { url in
            probe.calls.append(url)
            return try probe.reply.get()
        }, defaults: defaults, now: { probe.now })
    }

    // 실제 응답은 JSON 앞에 빈 줄이 붙어 온다(2026-10-03 curl).
    private func lookup(_ versions: String...) -> Data {
        let results = versions.map { #"{"trackId":6817888379,"bundleId":"com.itlearning.colormoments","version":"\#($0)"}"# }
        return Data("\n\n\n{\n \"resultCount\":\(versions.count),\n \"results\": [\(results.joined(separator: ","))]\n}\n".utf8)
    }

    func testComparesVersionsAsNumbers() {
        XCTAssertTrue(UpdateCheck.isNewer("1.10", than: "1.9"))
        XCTAssertTrue(UpdateCheck.isNewer("1.0.1", than: "1.0.0"))
        XCTAssertTrue(UpdateCheck.isNewer("1.1", than: "1.0.0"))
        XCTAssertTrue(UpdateCheck.isNewer("2", than: "1.99.99"))
        XCTAssertFalse(UpdateCheck.isNewer("1.9", than: "1.10"))
        XCTAssertFalse(UpdateCheck.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(UpdateCheck.isNewer("1.0", than: "1.0.0"))
        XCTAssertFalse(UpdateCheck.isNewer("1.0.0", than: "1.0"))
    }

    func testUnreadableVersionIsNeverNewer() {
        XCTAssertFalse(UpdateCheck.isNewer("1.1b", than: "1.0.0"))
        XCTAssertFalse(UpdateCheck.isNewer("", than: "1.0.0"))
        XCTAssertFalse(UpdateCheck.isNewer("1..1", than: "1.0.0"))
        XCTAssertFalse(UpdateCheck.isNewer("1.1", than: "?"))
    }

    func testShowsOnlyWhenStoreIsHigher() async {
        let probe = Probe()
        probe.reply = .success(lookup("1.1"))
        let result = await check(probe).newerVersion(than: "1.0.0")
        XCTAssertEqual(result, "1.1")
    }

    func testSameVersionHides() async {
        let probe = Probe()
        probe.reply = .success(lookup("1.0.0"))
        let result = await check(probe).newerVersion(than: "1.0.0")
        XCTAssertNil(result)
    }

    // 출시 직후엔 조회 결과가 몇 시간 늦게 바뀐다 — 스토어가 아직 옛 버전이면 숨긴다.
    func testStoreBehindInstalledHides() async {
        let probe = Probe()
        probe.reply = .success(lookup("1.0.0"))
        let result = await check(probe).newerVersion(than: "1.1")
        XCTAssertNil(result)
    }

    // 출시 전(지금)은 이렇게 온다.
    func testNoResultsHides() async {
        let probe = Probe()
        probe.reply = .success(lookup())
        let result = await check(probe).newerVersion(than: "1.0.0")
        XCTAssertNil(result)
    }

    func testFailureHides() async {
        let probe = Probe()
        probe.reply = .failure(URLError(.notConnectedToInternet))
        let result = await check(probe).newerVersion(than: "1.0.0")
        XCTAssertNil(result)
    }

    func testMalformedReplyHides() async {
        let probe = Probe()
        probe.reply = .success(Data("<html>oops</html>".utf8))
        var result = await check(probe).newerVersion(than: "1.0.0")
        XCTAssertNil(result)
        probe.reply = .success(Data(#"{"resultCount":1,"results":[{"trackId":1}]}"#.utf8))
        result = await check(probe).newerVersion(than: "1.0.0")
        XCTAssertNil(result)
    }

    func testAsksOnlyOnceADay() async {
        let probe = Probe()
        probe.reply = .success(lookup("1.1"))
        let c = check(probe)
        _ = await c.newerVersion(than: "1.0.0")
        probe.reply = .success(lookup("1.2"))
        probe.now += 23 * 3600
        let cached = await c.newerVersion(than: "1.0.0")
        XCTAssertEqual(cached, "1.1")
        XCTAssertEqual(probe.calls.count, 1)

        probe.now += 3600
        let fresh = await c.newerVersion(than: "1.0.0")
        XCTAssertEqual(fresh, "1.2")
        XCTAssertEqual(probe.calls.count, 2)
    }

    // 업데이트한 뒤 같은 날 다시 열면 담아 둔 스토어 버전과 새 번들 버전을 비교해 사라진다.
    func testCachedVersionIsComparedWithCurrentBundle() async {
        let probe = Probe()
        probe.reply = .success(lookup("1.1"))
        let c = check(probe)
        let before = await c.newerVersion(than: "1.0.0")
        let after = await c.newerVersion(than: "1.1")
        XCTAssertEqual(before, "1.1")
        XCTAssertNil(after)
        XCTAssertEqual(probe.calls.count, 1)
    }

    func testNoResultsIsAlsoKeptForADay() async {
        let probe = Probe()
        probe.reply = .success(lookup())
        let c = check(probe)
        _ = await c.newerVersion(than: "1.0.0")
        _ = await c.newerVersion(than: "1.0.0")
        XCTAssertEqual(probe.calls.count, 1)
    }

    func testFailureIsNotKept() async {
        let probe = Probe()
        probe.reply = .failure(URLError(.timedOut))
        let c = check(probe)
        _ = await c.newerVersion(than: "1.0.0")
        probe.reply = .success(lookup("1.1"))
        let result = await c.newerVersion(than: "1.0.0")
        XCTAssertEqual(result, "1.1")
        XCTAssertEqual(probe.calls.count, 2)
    }

    // 기기 시계를 앞으로 돌렸다 되돌리면 앞날에 적힌 기록이 남는다 — 그때는 다시 묻는다.
    func testCheckFromTheFutureIsIgnored() async {
        let probe = Probe()
        probe.reply = .success(lookup("1.1"))
        let c = check(probe)
        _ = await c.newerVersion(than: "1.0.0")
        probe.now -= 3600
        _ = await c.newerVersion(than: "1.0.0")
        XCTAssertEqual(probe.calls.count, 2)
    }

    func testRequestCarriesOnlyBundleIdAndCountry() async throws {
        let probe = Probe()
        probe.reply = .success(lookup("1.1"))
        _ = await check(probe).newerVersion(than: "1.0.0")
        let url = try XCTUnwrap(probe.calls.first)
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.scheme, "https")
        XCTAssertEqual(parts.host, "itunes.apple.com")
        XCTAssertEqual(parts.path, "/lookup")
        XCTAssertEqual(parts.queryItems, [URLQueryItem(name: "bundleId", value: "com.itlearning.colormoments"),
                                          URLQueryItem(name: "country", value: "kr")])
    }

    func testStoreLinkOpensAppStorePage() {
        XCTAssertEqual(UpdateCheck.storeURL.absoluteString, "itms-apps://apps.apple.com/app/id6817888379")
    }

    func testReviewLinkOpensWriteReview() {
        XCTAssertEqual(UpdateCheck.reviewURL.absoluteString,
                       "itms-apps://apps.apple.com/app/id6817888379?action=write-review")
    }

    func testSuggestionFormHiddenUntilAddressIsSet() {
        XCTAssertNil(SuggestionForm.link(nil))
        XCTAssertNil(SuggestionForm.link(""))
        XCTAssertNil(SuggestionForm.link("  "))
        XCTAssertNil(SuggestionForm.link("http://forms.gle/abc"))
        XCTAssertEqual(SuggestionForm.link("https://forms.gle/abc")?.absoluteString, "https://forms.gle/abc")
        XCTAssertEqual(SuggestionForm.url, SuggestionForm.link(SuggestionForm.address))
    }

    func testVersionLineUsesBundleValues() {
        let v = AppVersion(info: ["CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "2"])
        XCTAssertEqual(v.line, "버전 1.0.0 (2)")
        XCTAssertEqual(AppVersion.current.short, Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
    }
}
