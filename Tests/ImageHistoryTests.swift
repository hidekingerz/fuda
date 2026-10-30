import AppKit
import SwiftData
import XCTest
@testable import fuda

@MainActor
final class ImageHistoryTests: XCTestCase {
    private func pngData(width: Int, height: Int, color: NSColor = .red) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    func testPayloadNormalizesToPNGWithThumbnailAndHash() throws {
        let png = pngData(width: 400, height: 200)
        let payload = try XCTUnwrap(ImageProcessing.payload(from: png, maxBytes: 10_000_000))
        XCTAssertEqual(payload.width, 400)
        XCTAssertEqual(payload.height, 200)
        XCTAssertTrue(ImageProcessing.isPNG(payload.png))
        XCTAssertEqual(payload.hash, ImageProcessing.sha256(png))

        let thumb = try XCTUnwrap(NSBitmapImageRep(data: payload.thumbnail))
        XCTAssertEqual(thumb.pixelsWide, 96)
        XCTAssertEqual(thumb.pixelsHigh, 48)
    }

    func testTIFFIsConvertedToPNG() throws {
        let tiff = try XCTUnwrap(NSBitmapImageRep(data: pngData(width: 10, height: 10))?.tiffRepresentation)
        XCTAssertFalse(ImageProcessing.isPNG(tiff))
        let payload = try XCTUnwrap(ImageProcessing.payload(from: tiff, maxBytes: 10_000_000))
        XCTAssertTrue(ImageProcessing.isPNG(payload.png))
    }

    func testOversizedImageIsRejected() {
        XCTAssertNil(ImageProcessing.payload(from: pngData(width: 50, height: 50), maxBytes: 10))
    }

    func testRecordImageDeduplicatesByHashAndPrunesImagesSeparately() throws {
        let container = try PersistenceController.inMemory()
        let store = HistoryStore(context: container.mainContext)
        let colors: [NSColor] = [.red, .green, .blue, .yellow]
        for (i, color) in colors.enumerated() {
            let payload = try XCTUnwrap(ImageProcessing.payload(from: pngData(width: 8, height: 8, color: color), maxBytes: 1_000_000))
            try store.recordImage(payload, at: Date(timeIntervalSince1970: TimeInterval(i)), limit: 100, imageLimit: 2)
        }
        try store.record("text stays", at: Date(timeIntervalSince1970: 10), limit: 100)

        var items = try store.fetchAll()
        XCTAssertEqual(items.filter { $0.type == .image }.count, 2)
        XCTAssertEqual(items.filter { $0.type == .text }.count, 1)

        // 同じ画像をもう一度 → 件数は増えず先頭へ
        let again = try XCTUnwrap(ImageProcessing.payload(from: pngData(width: 8, height: 8, color: .blue), maxBytes: 1_000_000))
        try store.recordImage(again, at: Date(timeIntervalSince1970: 20), limit: 100, imageLimit: 2)
        items = try store.fetchAll()
        XCTAssertEqual(items.filter { $0.type == .image }.count, 2)
        XCTAssertEqual(items.first?.content, again.hash)
        XCTAssertEqual(PanelEntry.history(items[0]).title, "画像 8×8")
        XCTAssertNotNil(items[0].thumbnail)
    }
}
