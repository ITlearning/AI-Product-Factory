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

private struct FakeAssetImageSource: AssetImageSource {
    let knownIDs: Set<String>

    func image(assetID: String, maxPixel: CGFloat) -> UIImage? {
        guard knownIDs.contains(assetID) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }
}

final class ShotImageAssetSourceTests: XCTestCase {

    override func tearDown() {
        ShotImage.assetSource = nil
        super.tearDown()
    }

    func testMomentWithAssetIDAndSourceReadsFromSource() {
        ShotImage.assetSource = FakeAssetImageSource(knownIDs: ["ASSET-1"])
        let m = Moment(capturedAt: Date(), colorHex: "#112233",
                       fileName: Moment.assetFileName(for: "ASSET-1"), source: .library, assetID: "ASSET-1")

        XCTAssertNotNil(ShotImage.thumbnail(m, maxPixel: 100), "assetID 와 assetSource 가 있으면 에셋에서 읽어야 한다")
        XCTAssertNotNil(ShotImage.full(m))
    }

    func testMomentWithoutAssetIDReadsFromFile() throws {
        ShotImage.assetSource = FakeAssetImageSource(knownIDs: ["ASSET-1"])
        let src = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "IMG_2788", withExtension: "jpg", subdirectory: "Fixtures"))
        let name = "filebacked-\(UUID().uuidString).jpg"
        try Data(contentsOf: src).write(to: ShotImage.url(name))
        defer { try? FileManager.default.removeItem(at: ShotImage.url(name)) }
        let m = Moment(capturedAt: Date(), colorHex: "#112233", fileName: name, source: .app)

        XCTAssertNotNil(ShotImage.thumbnail(m, maxPixel: 100), "assetID 가 없으면 assetSource 가 꽂혀 있어도 파일에서 읽어야 한다")
    }

    func testUnknownAssetIDWithNoRealFileReturnsNil() {
        ShotImage.assetSource = FakeAssetImageSource(knownIDs: [])
        let m = Moment(capturedAt: Date(), colorHex: "#112233",
                       fileName: Moment.assetFileName(for: "MISSING"), source: .library, assetID: "MISSING")
        XCTAssertNil(ShotImage.thumbnail(m, maxPixel: 100),
                     "에셋도 못 찾고 그 이름의 파일도 없으면 nil 이어야 한다")
    }

    func testUnknownAssetIDFallsBackToFileWhenOneExists() throws {
        ShotImage.assetSource = FakeAssetImageSource(knownIDs: [])
        let src = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "IMG_2788", withExtension: "jpg", subdirectory: "Fixtures"))
        let name = "library-\(UUID().uuidString).jpg"
        try Data(contentsOf: src).write(to: ShotImage.url(name))
        defer { try? FileManager.default.removeItem(at: ShotImage.url(name)) }
        let m = Moment(capturedAt: Date(), colorHex: "#112233", fileName: name, source: .library, assetID: "MISSING")

        XCTAssertNotNil(ShotImage.thumbnail(m, maxPixel: 100),
                        "에셋을 못 찾아도 그 fileName 에 아직 파일이 남아있으면 파일로 폴백해야 한다(기기 복원 등)")
    }
}
