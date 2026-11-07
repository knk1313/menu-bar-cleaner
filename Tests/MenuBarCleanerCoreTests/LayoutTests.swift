import CoreGraphics
import XCTest
@testable import MenuBarCleanerCore

final class LayoutTests: XCTestCase {
    func test折りたたみの長さは最も広い画面より長い() {
        let length = Layout.collapsedSeparatorLength(screenWidths: [1728, 2560])
        XCTAssertGreaterThan(length, 2560)
    }

    func test折りたたみの長さは上限を超えない() {
        let length = Layout.collapsedSeparatorLength(screenWidths: [20_000])
        XCTAssertEqual(length, Layout.maxSeparatorLength)
    }

    func test画面が取れないときも項目を押し出せる長さにする() {
        let length = Layout.collapsedSeparatorLength(screenWidths: [])
        XCTAssertGreaterThanOrEqual(length, 1_000)
    }

    func test区切りがトグルの左なら正しい並び() {
        XCTAssertTrue(Layout.isOrderValid(separatorMinX: 1000, toggleMinX: 1020))
        XCTAssertFalse(Layout.isOrderValid(separatorMinX: 1020, toggleMinX: 1000))
    }

    func test境目より左の項目だけを隠れていると判定する() {
        let left = CGRect(x: 900, y: 0, width: 24, height: 24)
        let right = CGRect(x: 1100, y: 0, width: 24, height: 24)
        XCTAssertTrue(Layout.isHidden(itemFrame: left, boundaryMinX: 1000))
        XCTAssertFalse(Layout.isHidden(itemFrame: right, boundaryMinX: 1000))
    }

    func test折りたたみ中に画面外へ出た項目も隠れていると判定する() {
        let offscreen = CGRect(x: -3000, y: 0, width: 24, height: 24)
        XCTAssertTrue(Layout.isHidden(itemFrame: offscreen, boundaryMinX: -1500))
    }
}
