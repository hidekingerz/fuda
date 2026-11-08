// アプリアイコンとメニューバー用テンプレート画像を描画する。
// 使い方: swift scripts/render-icon.swift <出力ディレクトリ>
//   <dir>/tag-layer.png      Icon Composer（Sources/AppIcon.icon/Assets/tag.png）用の札レイヤー（1024px、透過）
//   <dir>/menubar@2x.png     メニューバー用テンプレート（36px、黒のみ）
//   <dir>/menubar.png        同 18px
// 背景色・影・ガラス表現は Sources/AppIcon.icon/icon.json 側で指定する。
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// MARK: - 札の形

/// 上辺の角を落とした縦長の札。bounds の中に収まるパスを返す。
func tagPath(in r: CGRect) -> NSBezierPath {
    let chamfer = r.width * 0.18
    let p = NSBezierPath()
    p.move(to: CGPoint(x: r.minX, y: r.minY))
    p.line(to: CGPoint(x: r.minX, y: r.maxY - chamfer))
    p.line(to: CGPoint(x: r.minX + chamfer, y: r.maxY))
    p.line(to: CGPoint(x: r.maxX - chamfer, y: r.maxY))
    p.line(to: CGPoint(x: r.maxX, y: r.maxY - chamfer))
    p.line(to: CGPoint(x: r.maxX, y: r.minY))
    p.close()
    return p
}

/// 札（穴・紐・横線つき）を描く。size は描画領域の一辺。template が true なら黒一色の輪郭版。
func drawTag(canvas: CGFloat, template: Bool, shadow: Bool = true) {
    let tagW = canvas * 0.44
    let tagH = canvas * 0.64
    let center = CGPoint(x: canvas / 2, y: canvas / 2 - canvas * 0.02)
    let rect = CGRect(x: center.x - tagW / 2, y: center.y - tagH / 2, width: tagW, height: tagH)

    let xform = NSAffineTransform()
    xform.translateX(by: center.x, yBy: center.y)
    xform.rotate(byDegrees: -8)
    xform.translateX(by: -center.x, yBy: -center.y)

    NSGraphicsContext.saveGraphicsState()
    xform.concat()

    let body = tagPath(in: rect)
    let holeR = tagW * 0.075
    let holeCenter = CGPoint(x: rect.midX, y: rect.maxY - tagW * 0.22)
    let hole = NSBezierPath(ovalIn: CGRect(x: holeCenter.x - holeR, y: holeCenter.y - holeR, width: holeR * 2, height: holeR * 2))

    if template {
        // 黒で塗り、穴と横線を抜く
        let cut = NSBezierPath(); cut.append(body); cut.append(hole)
        cut.windingRule = .evenOdd
        NSColor.black.setFill(); cut.fill()
        NSColor.clear.setFill()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        let lineW = tagW * 0.56, lineH = tagH * 0.055
        for i in 0..<3 {
            let y = rect.minY + tagH * (0.42 - CGFloat(i) * 0.14) - lineH / 2
            NSBezierPath(roundedRect: CGRect(x: rect.midX - lineW / 2, y: y, width: lineW * (i == 2 ? 0.7 : 1), height: lineH),
                         xRadius: lineH / 2, yRadius: lineH / 2).fill()
        }
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    } else {
        // 影
        NSGraphicsContext.saveGraphicsState()
        if shadow {
            let drop = NSShadow()
            drop.shadowColor = NSColor.black.withAlphaComponent(0.35)
            drop.shadowBlurRadius = canvas * 0.03
            drop.shadowOffset = NSSize(width: 0, height: -canvas * 0.015)
            drop.set()
        }
        NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.85, alpha: 1).setFill()
        body.fill()
        NSGraphicsContext.restoreGraphicsState()

        // 札の面にわずかなグラデーション
        NSGraphicsContext.saveGraphicsState()
        body.addClip()
        NSGradient(starting: NSColor(calibratedRed: 0.99, green: 0.97, blue: 0.91, alpha: 1),
                   ending: NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.80, alpha: 1))!
            .draw(in: rect, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // 縁取り
        NSColor(calibratedRed: 0.72, green: 0.64, blue: 0.50, alpha: 1).setStroke()
        body.lineWidth = canvas * 0.008
        body.stroke()

        // 横線（履歴の項目）
        let lineW = tagW * 0.56, lineH = tagH * 0.045
        NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.40, alpha: 0.85).setFill()
        for i in 0..<3 {
            let y = rect.minY + tagH * (0.42 - CGFloat(i) * 0.14) - lineH / 2
            NSBezierPath(roundedRect: CGRect(x: rect.midX - lineW / 2, y: y, width: lineW * (i == 2 ? 0.7 : 1), height: lineH),
                         xRadius: lineH / 2, yRadius: lineH / 2).fill()
        }

        // 穴
        NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.28, alpha: 1).setFill()
        hole.fill()
        NSColor(calibratedRed: 0.72, green: 0.64, blue: 0.50, alpha: 1).setStroke()
        hole.lineWidth = canvas * 0.006
        hole.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    // 紐（回転の外で描き、穴から上へ抜ける輪）
    let knot = xform.transform(holeCenter)
    let string = NSBezierPath()
    string.move(to: knot)
    string.curve(to: CGPoint(x: knot.x + canvas * 0.10, y: knot.y + canvas * 0.20),
                 controlPoint1: CGPoint(x: knot.x - canvas * 0.06, y: knot.y + canvas * 0.10),
                 controlPoint2: CGPoint(x: knot.x - canvas * 0.02, y: knot.y + canvas * 0.22))
    string.curve(to: knot,
                 controlPoint1: CGPoint(x: knot.x + canvas * 0.18, y: knot.y + canvas * 0.18),
                 controlPoint2: CGPoint(x: knot.x + canvas * 0.10, y: knot.y + canvas * 0.04))
    string.lineWidth = canvas * (template ? 0.045 : 0.022)
    string.lineCapStyle = .round
    string.lineJoinStyle = .round
    (template ? NSColor.black : NSColor(calibratedRed: 0.80, green: 0.18, blue: 0.20, alpha: 1)).setStroke()
    string.stroke()
}

// MARK: - 出力

func render(size: Int, template: Bool, draw: (CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Icon Composer（.icon）用: 札だけを透過で描く。影と背景は OS 側が付ける
let tagLayer = render(size: 1024, template: false) { canvas in
    drawTag(canvas: canvas, template: false, shadow: false)
}
try tagLayer.write(to: outDir.appendingPathComponent("tag-layer.png"))

// メニューバー用テンプレート（18pt）。小さいので紐は省き、札と穴と 2 本の横線だけにする。
func drawMenuBarTag(canvas: CGFloat) {
    let tagW = canvas * 0.62, tagH = canvas * 0.9
    let rect = CGRect(x: (canvas - tagW) / 2, y: (canvas - tagH) / 2, width: tagW, height: tagH)
    NSColor.black.setFill()
    tagPath(in: rect).fill()

    // 穴と横線を抜く
    NSGraphicsContext.current?.compositingOperation = .destinationOut
    let holeR = canvas * 0.07
    NSBezierPath(ovalIn: CGRect(x: rect.midX - holeR, y: rect.maxY - canvas * 0.16 - holeR, width: holeR * 2, height: holeR * 2)).fill()
    let lineH = max(canvas * 0.07, 1), lineW = tagW * 0.6
    for i in 0..<2 {
        let y = rect.minY + tagH * (0.42 - CGFloat(i) * 0.18) - lineH / 2
        NSBezierPath(rect: CGRect(x: rect.midX - lineW / 2, y: y, width: lineW, height: lineH)).fill()
    }
    NSGraphicsContext.current?.compositingOperation = .sourceOver
}

for (scale, name) in [(1, "menubar.png"), (2, "menubar@2x.png")] {
    let data = render(size: 18 * scale, template: true) { canvas in drawMenuBarTag(canvas: canvas) }
    try data.write(to: outDir.appendingPathComponent(name))
}
print("wrote to \(outDir.path)")
