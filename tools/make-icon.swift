// Draws the app icon into dsporganizerApp/Assets.xcassets/AppIcon.appiconset.
//   swift tools/make-icon.swift
// Two screens side by side, an alignment line across the seam and ruler ticks at it.

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let output = "dsporganizerApp/Assets.xcassets/AppIcon.appiconset"

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

/// Draws in a 1024×1024 top-left-origin space, scaled to `size` pixels.
func render(size: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let s = CGFloat(size) / 1024
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: s, y: -s)

    func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }
    func gradient(_ path: CGPath, _ top: CGColor, _ bottom: CGColor, _ r: CGRect) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let g = CGGradient(colorsSpace: nil, colors: [top, bottom] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.minY), end: CGPoint(x: r.midX, y: r.maxY), options: [])
        ctx.restoreGState()
    }

    // body: the macOS icon grid, 824pt rounded square centred on the 1024 canvas
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = rounded(body, 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0.10, 0.17, 0.40))
    ctx.fillPath()
    ctx.restoreGState()
    gradient(bodyPath, color(0.20, 0.36, 0.72), color(0.07, 0.11, 0.30), body)

    // two screens touching at x = 470: a portrait one and a landscape one
    let seam: CGFloat = 470
    let left = CGRect(x: 200, y: 260, width: seam - 200, height: 470)
    let right = CGRect(x: seam, y: 365, width: 830 - seam, height: 260)
    for r in [left, right] {
        let frame = rounded(r, 26)
        ctx.addPath(frame)
        ctx.setFillColor(color(0.06, 0.08, 0.16))
        ctx.fillPath()
        let screen = r.insetBy(dx: 16, dy: 16)
        gradient(rounded(screen, 12), color(0.55, 0.86, 1.0), color(0.20, 0.52, 0.95), screen)
    }

    // ruler ticks along the seam, on both screens
    ctx.setStrokeColor(color(1, 1, 1, 0.9))
    for (i, y) in stride(from: right.minY + 30, through: right.maxY - 30, by: 25).enumerated() {
        let length: CGFloat = i % 4 == 0 ? 46 : 24
        ctx.setLineWidth(i % 4 == 0 ? 7 : 5)
        ctx.move(to: CGPoint(x: seam - length, y: y))
        ctx.addLine(to: CGPoint(x: seam + length, y: y))
        ctx.strokePath()
    }

    // the alignment line, straight across both screens
    let y = right.minY + 30 + 25 * 4
    ctx.setStrokeColor(color(1.0, 0.80, 0.15))
    ctx.setLineWidth(16)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: left.minX + 50, y: y))
    ctx.addLine(to: CGPoint(x: right.maxX - 50, y: y))
    ctx.strokePath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest), "cannot write \(path)")
}

try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
var images: [String] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        write(render(size: points * scale), to: "\(output)/\(name)")
        images.append("""
            { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(scale)x", "size" : "\(points)x\(points)" }
        """)
    }
}
let contents = """
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

"""
try contents.write(toFile: "\(output)/Contents.json", atomically: true, encoding: .utf8)
try """
{
  "info" : { "author" : "xcode", "version" : 1 }
}

""".write(toFile: "dsporganizerApp/Assets.xcassets/Contents.json", atomically: true, encoding: .utf8)
print("written to \(output)")
