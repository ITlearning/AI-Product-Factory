import CoreImage
import UIKit
import XCTest
@testable import ColorMoments

final class ShotImageTests: XCTestCase {

    func testThumbnailIsOrientedAndSmall() throws {
        let src = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "IMG_5005", withExtension: "jpg", subdirectory: "Fixtures"))
        let name = "thumbtest-\(UUID().uuidString).jpg"
        try Data(contentsOf: src).write(to: ShotImage.url(name))
        defer { try? FileManager.default.removeItem(at: ShotImage.url(name)) }

        let full = try XCTUnwrap(ShotImage.full(name))
        let thumb = try XCTUnwrap(ShotImage.thumbnail(name, maxPixel: 120))
        XCTAssertLessThanOrEqual(max(thumb.size.width, thumb.size.height), 120,
                                 "축소가 안 됐다 — 격자에 원본이 올라간다")
        XCTAssertEqual(thumb.size.width / thumb.size.height,
                       full.size.width / full.size.height, accuracy: 0.05,
                       "축소본 비율이 원본과 다르다 — 방향이 다르게 적용됐다")
    }
}

final class ShotImageCacheTests: XCTestCase {

    private var shot: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let src = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "IMG_2788", withExtension: "jpg", subdirectory: "Fixtures"))
        shot = "cache-\(UUID().uuidString).jpg"
        try Data(contentsOf: src).write(to: ShotImage.url(shot))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: ShotImage.url(shot))
        super.tearDown()
    }

    func testWarmThenPeekReturnsSameInstance() throws {
        XCTAssertNil(ShotImage.peek(shot, maxPixel: 300), "데우기 전인데 캐시에 있다")
        let first = try XCTUnwrap(ShotImage.warm(shot, maxPixel: 300))
        let peeked = try XCTUnwrap(ShotImage.peek(shot, maxPixel: 300), "데웠는데 캐시에 없다")
        XCTAssertTrue(first === peeked, "캐시를 지나치고 다시 디코드했다")
        XCTAssertTrue(first === ShotImage.warm(shot, maxPixel: 300), "warm 이 캐시를 안 쓴다")
    }

    func testDifferentSizesAreSeparateEntries() throws {
        let small = try XCTUnwrap(ShotImage.warm(shot, maxPixel: 200))
        let large = try XCTUnwrap(ShotImage.warm(shot, maxPixel: 600))
        XCTAssertFalse(small === large)
        XCTAssertLessThan(max(small.size.width, small.size.height), 210)
        XCTAssertGreaterThan(max(large.size.width, large.size.height), 210)
    }

    func testMissingFileIsHandled() {
        XCTAssertNil(ShotImage.warm("없는파일-\(UUID().uuidString).jpg", maxPixel: 300))
    }
}
