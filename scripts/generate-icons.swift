#!/usr/bin/env swift
// Goto terminal-frame-stack icon generator.
// Renders the canonical artwork at any size, emits:
//   - tmp/AppIcon.iconset/* (PNG)
//   - Resources/applet.icns (via iconutil)
//   - Resources/goto-glyph.pdf (template glyph for menu bar / Finder Sync)
import AppKit
import CoreGraphics
import Foundation

let projectRoot = ProcessInfo.processInfo.environment["GOTO_PROJECT_ROOT"]
    ?? FileManager.default.currentDirectoryPath
let resources = projectRoot + "/Resources"
let tmp = projectRoot + "/tmp/AppIcon.iconset"

try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: resources, withIntermediateDirectories: true)

enum Style { case color, mono }

func draw(in rect: CGRect, style: Style, ctx: CGContext) {
    let s = rect.width / 1024.0
    func sx(_ v: CGFloat) -> CGFloat { v * s }
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + sx(x), y: rect.minY + sx(1024 - y))
    }
    func svgRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX + sx(x),
            y: rect.minY + sx(1024 - y - height),
            width: sx(width),
            height: sx(height)
        )
    }

    if style == .color {
        ctx.setFillColor(NSColor(red: 0x0b/255.0, green: 0x12/255.0, blue: 0x20/255.0, alpha: 1).cgColor)
        let bg = CGPath(roundedRect: rect, cornerWidth: sx(220), cornerHeight: sx(220), transform: nil)
        ctx.addPath(bg)
        ctx.fillPath()
    }
    // mono: PDF context starts transparent; do NOT call ctx.clear() —
    // CGPDFContext renders clear() as a filled rectangle in the current color,
    // which makes the entire glyph a solid black square (template => white square).

    let inkBlack = NSColor.black
    let inkSlate = NSColor(red: 0x33/255.0, green: 0x41/255.0, blue: 0x55/255.0, alpha: 1)
    let inkMint = NSColor(red: 0x9e/255.0, green: 1.0, blue: 0x8a/255.0, alpha: 1)
    let inkText = NSColor(red: 0xf8/255.0, green: 0xfa/255.0, blue: 0xfc/255.0, alpha: 1)

    let frameColor = (style == .color) ? inkSlate.cgColor : inkBlack.cgColor
    let markColor = (style == .color) ? inkMint.cgColor : inkBlack.cgColor
    let textColor = (style == .color) ? inkText : inkBlack

    // Terminal frame from the selected "Terminal Frame Stack" concept.
    let frame = CGPath(
        roundedRect: svgRect(x: 156, y: 144, width: 712, height: 736),
        cornerWidth: sx(64),
        cornerHeight: sx(64),
        transform: nil
    )
    ctx.setStrokeColor(frameColor)
    ctx.setLineWidth(sx(72))
    ctx.addPath(frame)
    ctx.strokePath()

    // Prompt chevron, converted from the SVG prototype.
    let prompt = CGMutablePath()
    prompt.move(to: point(284, 234))
    prompt.addLine(to: point(516, 384))
    prompt.addLine(to: point(284, 534))
    prompt.addLine(to: point(284, 418))
    prompt.addLine(to: point(370, 384))
    prompt.addLine(to: point(284, 350))
    prompt.closeSubpath()
    ctx.setFillColor(markColor)
    ctx.addPath(prompt)
    ctx.fillPath()

    // Cursor block.
    ctx.setFillColor(markColor)
    ctx.fill(svgRect(x: 552, y: 450, width: 184, height: 76))

    // "goto" wordmark. The PDF glyph remains vector text; if this ever needs
    // distribution as a standalone SVG, convert the wordmark to outlines first.
    let str = "goto" as NSString
    let fontSize = sx(192)
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .black)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor
    ]
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    str.draw(at: NSPoint(x: rect.minX + sx(228), y: rect.minY + sx(1024 - 756)), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
}

func renderPNG(size: Int, to path: String) {
    let pixelSize = CGSize(width: size, height: size)
    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmap = CGContext(
        data: nil,
        width: size, height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    bitmap.interpolationQuality = .high
    let rect = CGRect(origin: .zero, size: pixelSize)
    draw(in: rect, style: .color, ctx: bitmap)
    guard let cg = bitmap.makeImage() else { return }
    let rep = NSBitmapImageRep(cgImage: cg)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(size)x\(size))")
}

func renderPDF(side: CGFloat, style: Style, to path: String) {
    var box = CGRect(x: 0, y: 0, width: side, height: side)
    let url = URL(fileURLWithPath: path) as CFURL
    let ctx = CGContext(url, mediaBox: &box, nil)!
    ctx.beginPDFPage(nil)
    draw(in: box, style: style, ctx: ctx)
    ctx.endPDFPage()
    ctx.closePDF()
    print("wrote \(path) (PDF \(Int(side))pt)")
}

// Apple iconset spec (1x + 2x for each base size 16/32/128/256/512)
let specs: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (px, name) in specs {
    renderPNG(size: px, to: tmp + "/" + name)
}

// Glyph PDF for menu bar / Finder Sync (template image, monochrome black)
renderPDF(side: 64, style: .mono, to: resources + "/goto-glyph.pdf")

// Compile iconset -> applet.icns via iconutil so the Finder app-bundle icon
// stays in sync with the PNGs we just wrote.
let icnsOut = resources + "/applet.icns"
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", tmp, "-o", icnsOut]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed with status \(task.terminationStatus)\n".utf8))
    exit(task.terminationStatus)
}
print("wrote \(icnsOut)")

print("ok")
