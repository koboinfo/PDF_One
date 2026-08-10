// Renders AppIconGraphic (Sources/Views/Components/AppIconView.swift) to a
// flat, alpha-free 1024x1024 PNG for Assets.xcassets/AppIcon.appiconset.
//
// Usage:
//   swiftc -parse-as-library Sources/Views/Components/AppIconView.swift Scripts/generate_app_icon.swift \
//     -o /tmp/generate_app_icon && /tmp/generate_app_icon \
//     Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import SwiftUI
import AppKit
import CoreGraphics

@main
struct GenerateAppIcon {
    static func main() throws {
        let size: CGFloat = 1024
        let renderer = ImageRenderer(content: AppIconGraphic().frame(width: size, height: size))
        renderer.scale = 1

        guard let cgImage = renderer.cgImage else {
            fatalError("Failed to render AppIconGraphic")
        }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            fatalError("Failed to create flattening context")
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let flattened = context.makeImage() else {
            fatalError("Failed to flatten rendered image")
        }

        let rep = NSBitmapImageRep(cgImage: flattened)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            fatalError("Failed to encode PNG")
        }

        let outputPath = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : "AppIcon.png"

        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Wrote \(outputPath) (\(width)x\(height), no alpha)")
    }
}
