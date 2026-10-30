import AppKit
import CryptoKit
import Foundation

/// 履歴に保存する画像の正規化結果。
struct ImagePayload: Equatable {
    /// PNG に正規化したデータ。
    let png: Data
    let width: Int
    let height: Int
    /// 一覧表示用の縮小 PNG。
    let thumbnail: Data
    /// png の SHA-256（重複判定用）。
    let hash: String
}

enum ImageProcessing {
    static let thumbnailMaxSize = CGSize(width: 96, height: 64)

    /// PNG または TIFF などのデータから、PNG に正規化したペイロードを作る。
    /// maxBytes を超える場合は nil。
    static func payload(from data: Data, maxBytes: Int) -> ImagePayload? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        let png: Data
        if isPNG(data) {
            png = data
        } else {
            guard let converted = rep.representation(using: .png, properties: [:]) else { return nil }
            png = converted
        }
        guard png.count <= maxBytes, rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return nil }
        guard let thumbnail = thumbnail(from: rep) else { return nil }
        return ImagePayload(
            png: png,
            width: rep.pixelsWide,
            height: rep.pixelsHigh,
            thumbnail: thumbnail,
            hash: sha256(png)
        )
    }

    static func isPNG(_ data: Data) -> Bool {
        data.count >= 8 && data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// アスペクト比を保って thumbnailMaxSize に収めた PNG。
    static func thumbnail(from rep: NSBitmapImageRep, maxSize: CGSize = thumbnailMaxSize) -> Data? {
        let scale = min(maxSize.width / CGFloat(rep.pixelsWide), maxSize.height / CGFloat(rep.pixelsHigh), 1)
        let size = NSSize(
            width: max(1, (CGFloat(rep.pixelsWide) * scale).rounded()),
            height: max(1, (CGFloat(rep.pixelsHigh) * scale).rounded())
        )
        guard let target = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: target)
        NSGraphicsContext.current?.imageInterpolation = .high
        rep.draw(in: NSRect(origin: .zero, size: size))
        return target.representation(using: .png, properties: [:])
    }

    static func sizeText(bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
