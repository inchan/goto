#!/usr/bin/env swift
// Goto P03 mint-prompt icon generator.
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

    if style == .color {
        ctx.setFillColor(NSColor(red: 0x0b/255.0, green: 0x12/255.0, blue: 0x20/255.0, alpha: 1).cgColor)
        let bg = CGPath(roundedRect: rect, cornerWidth: sx(220), cornerHeight: sx(220), transform: nil)
        ctx.addPath(bg)
        ctx.fillPath()
    }
    // mono: PDF context starts transparent; do NOT call ctx.clear() —
    // CGPDFContext renders clear() as a filled rectangle in the current color,
    // which makes the entire glyph a solid black square (template => white square).

    let inkBlack = NSColor.black.cgColor
    let inkSlate = NSColor(red: 0x33/255.0, green: 0x41/255.0, blue: 0x55/255.0, alpha: 1).cgColor
    let inkMint  = NSColor(red: 0x9e/255.0, green: 1.0, blue: 0x8a/255.0, alpha: 1).cgColor
    let inkPromptOnMint = NSColor(red: 0x0b/255.0, green: 0x12/255.0, blue: 0x20/255.0, alpha: 1).cgColor

    let leftStroke  = (style == .color) ? inkSlate : inkBlack
    let rightStroke = (style == .color) ? inkMint  : inkBlack
    let arrowStroke = (style == .color) ? inkMint  : inkBlack
    let promptFill  = (style == .color) ? inkPromptOnMint : inkBlack

    let portalLineW = sx(40)
    let arrowLineW  = sx(60)

    func ellipsePath(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> CGPath {
        let r = CGRect(x: rect.minX + sx(cx) - sx(rx), y: rect.minY + sx(cy) - sx(ry), width: sx(rx)*2, height: sx(ry)*2)
        return CGPath(ellipseIn: r, transform: nil)
    }

    // Left portal
    ctx.setLineWidth(portalLineW)
    ctx.setStrokeColor(leftStroke)
    ctx.addPath(ellipsePath(cx: 320, cy: 512, rx: 140, ry: 220))
    ctx.strokePath()

    // Right portal — for mono, use a hairline-friendly identical stroke; in color, mint
    ctx.setLineWidth(portalLineW)
    ctx.setStrokeColor(rightStroke)
    ctx.addPath(ellipsePath(cx: 704, cy: 512, rx: 140, ry: 220))
    ctx.strokePath()

    // Arrow shaft + chevron head (matches P03 SVG verbatim)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(arrowLineW)
    ctx.setStrokeColor(arrowStroke)
    let shaft = CGMutablePath()
    shaft.move(to: CGPoint(x: rect.minX + sx(380), y: rect.minY + sx(512)))
    shaft.addLine(to: CGPoint(x: rect.minX + sx(660), y: rect.minY + sx(512)))
    ctx.addPath(shaft); ctx.strokePath()

    let head = CGMutablePath()
    head.move(to: CGPoint(x: rect.minX + sx(600), y: rect.minY + sx(512 - 80)))
    head.addLine(to: CGPoint(x: rect.minX + sx(700), y: rect.minY + sx(512)))
    head.addLine(to: CGPoint(x: rect.minX + sx(600), y: rect.minY + sx(512 + 80)))
    ctx.addPath(head); ctx.strokePath()

    // Prompt glyph "❯" centered in the right portal — color only.
    // Per P03: dark (#0b1220) on dark portal interior, intentionally subtle.
    if style == .color {
        let str = "❯" as NSString
        let fontSize = sx(180)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .black)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: promptFill) ?? .black
        ]
        let size = str.size(withAttributes: attrs)
        let x = rect.minX + sx(704) - size.width/2
        let y = rect.minY + sx(512) - size.height/2 + sx(8)
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        str.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }
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
