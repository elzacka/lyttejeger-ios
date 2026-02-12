#!/usr/bin/env swift

import AppKit
import Foundation

// MARK: - Config

let projectRoot = "/Users/lene/dev/lyttejeger-ios"
let assetsPath = "\(projectRoot)/Lyttejeger/Resources/Assets.xcassets"

// Try original source first, fall back to extracting from current app icon
let sourcePath = "\(projectRoot)/Headphones.png"
let fallbackPath = "\(assetsPath)/AppIcon.appiconset/AppIcon.png"
let oldPadding: CGFloat = 140 // padding used in previous icon generation

let sourceImage: NSImage
let needsCrop: Bool

if let img = NSImage(contentsOfFile: sourcePath) {
    sourceImage = img
    needsCrop = false
    print("Using source: Headphones.png")
} else if let img = NSImage(contentsOfFile: fallbackPath) {
    // Crop out the old padding to extract the headphones
    let full = img.size
    let cropOrigin = oldPadding
    let cropSize = full.width - oldPadding * 2
    let cropRect = NSRect(x: cropOrigin, y: cropOrigin, width: cropSize, height: cropSize)

    let cropped = NSImage(size: NSSize(width: cropSize, height: cropSize))
    cropped.lockFocus()
    img.draw(in: NSRect(x: 0, y: 0, width: cropSize, height: cropSize),
             from: cropRect, operation: .copy, fraction: 1.0)
    cropped.unlockFocus()

    sourceImage = cropped
    needsCrop = true
    print("Using source: existing AppIcon.png (cropped)")
} else {
    fatalError("Cannot load source image. Place Headphones.png at project root or ensure AppIcon.png exists.")
}

// MARK: - Helpers

func renderPNG(size: Int, draw: (NSGraphicsContext) -> Void) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    ctx.shouldAntialias = true
    NSGraphicsContext.current = ctx
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

func savePNG(_ data: Data, to path: String) {
    try! data.write(to: URL(fileURLWithPath: path))
    print("Generated: \(path)")
}

// MARK: - App Icon (1024x1024, beige bg + headphones)

let iconSize = 1024
let padding: CGFloat = 60
let iconData = renderPNG(size: iconSize) { _ in
    // Beige background (#F4F1EA)
    NSColor(red: 0xF4/255.0, green: 0xF1/255.0, blue: 0xEA/255.0, alpha: 1.0).setFill()
    NSRect(x: 0, y: 0, width: iconSize, height: iconSize).fill()

    // Draw headphones centered with padding
    let s = CGFloat(iconSize)
    let drawRect = NSRect(x: padding, y: padding, width: s - padding * 2, height: s - padding * 2)
    sourceImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
}
savePNG(iconData, to: "\(assetsPath)/AppIcon.appiconset/AppIcon.png")

// MARK: - Launch Logo (transparent bg, headphones only)

for (suffix, size) in [("LaunchLogo.png", 80), ("LaunchLogo@2x.png", 160), ("LaunchLogo@3x.png", 240)] {
    let logoData = renderPNG(size: size) { _ in
        let s = CGFloat(size)
        sourceImage.draw(in: NSRect(x: 0, y: 0, width: s, height: s), from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    savePNG(logoData, to: "\(assetsPath)/LaunchLogo.imageset/\(suffix)")
}

print("All icons generated successfully.")
