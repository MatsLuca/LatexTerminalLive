import AppKit
import CoreGraphics

struct CoordinateTransform {
    /// Converts a rect from ScreenCaptureKit coordinate space (origin top-left)
    /// to AppKit coordinate space (origin bottom-left).
    ///
    /// SCK: (0,0) is top-left of the primary screen.
    /// AppKit: (0,0) is bottom-left of the primary screen.
    static func sckFrameToAppKit(_ sckFrame: CGRect) -> CGRect {
        // The primary screen is defined as the one with origin (0,0) in AppKit.
        guard let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first else {
            return sckFrame
        }
        
        let primaryHeight = primaryScreen.frame.height
        
        // SCK origin is top-left of primary screen.
        // AppKit origin is bottom-left of primary screen.
        let appKitY = primaryHeight - sckFrame.origin.y - sckFrame.height
        
        let result = CGRect(
            x: sckFrame.origin.x,
            y: appKitY,
            width: sckFrame.width,
            height: sckFrame.height
        )

        DebugLog.coordinates("SCK \(sckFrame) -> AppKit \(result) (Primary Height: \(primaryHeight))")
        return result
    }
}

