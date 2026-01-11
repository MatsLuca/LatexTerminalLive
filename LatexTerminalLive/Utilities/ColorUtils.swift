import CoreGraphics
import SwiftUI

struct AppTheme {
    let backgroundColor: Color
    let foregroundColor: Color
}

class ColorUtils {
    static func sampleColor(at point: CGPoint, in image: CGImage) -> Color? {
        let width = image.width
        let height = image.height
        
        let x = Int(point.x)
        let y = Int(point.y)
        
        guard x >= 0 && x < width, y >= 0 && y < height else { return nil }
        
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return nil
        }
        
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        let offset = (y * bytesPerRow) + (x * bytesPerPixel)
        
        // Assuming RGBA8888 or BGRA8888 - common for screenshots
        let b = Double(ptr[offset]) / 255.0
        let g = Double(ptr[offset + 1]) / 255.0
        let r = Double(ptr[offset + 2]) / 255.0
        // ptr[offset + 3] is Alpha
        
        return Color(red: r, green: g, blue: b)
    }
    
    static func detectTheme(from image: CGImage, textItems: [RecognizedTextItem]) -> AppTheme {
        // 1. Detect Background: Sample a few points around the edges
        let cornerPoints = [
            CGPoint(x: 10, y: 10),
            CGPoint(x: CGFloat(image.width - 10), y: 10),
            CGPoint(x: 10, y: CGFloat(image.height - 10)),
            CGPoint(x: CGFloat(image.width - 10), y: CGFloat(image.height - 10))
        ]
        
        var bgColors: [Color] = []
        for p in cornerPoints {
            if let color = sampleColor(at: p, in: image) {
                bgColors.append(color)
            }
        }
        
        // Simple average for now, could be more robust
        let bgColor = bgColors.first ?? Color(red: 0.12, green: 0.12, blue: 0.12)
        
        // 2. Detect Foreground: Sample the first few text items
        // We look for a pixel that is significantly different from background
        var fgColor = Color.white
        
        outerLoop: for item in textItems.prefix(5) {
            let box = item.boundingBox // Normalized 0...1
            let x = Int(box.origin.x * CGFloat(image.width))
            let y = Int((1.0 - box.origin.y - box.size.height) * CGFloat(image.height))
            let w = Int(box.size.width * CGFloat(image.width))
            let h = Int(box.size.height * CGFloat(image.height))
            
            // Sample a small grid within the text box to find the brightest/most distinct pixel
            for dx in stride(from: 2, to: w, by: w/4) {
                for dy in stride(from: 2, to: h, by: h/4) {
                    if let color = sampleColor(at: CGPoint(x: x + dx, y: y + dy), in: image) {
                        // If it's different enough from BG, assume it's text
                        // (Very naive: just check if it's "lighter" or "darker")
                        // For now, let's just take the first one that isn't exactly the BG color
                        if color != bgColor {
                            fgColor = color
                            break outerLoop
                        }
                    }
                }
            }
        }
        
        return AppTheme(backgroundColor: bgColor, foregroundColor: fgColor)
    }
}
