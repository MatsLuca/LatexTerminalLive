import AppKit
import ScreenCaptureKit
import OSLog
import SwiftUI

class ScreenCaptureManager: NSObject {
    private let logger = Logger(subsystem: "com.antigravity.LatexTerminalLive", category: "Capture")
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        // SCStream requires screen recording permissions.
        // On macOS 14+, we can check it using CGPreflightScreenCaptureAccess()
        // and trigger the request.
        let hasAccess = CGPreflightScreenCaptureAccess()
        if !hasAccess {
            CGRequestScreenCaptureAccess()
            // We usually can't get a completion from this, so we advise the user
            // to check settings. 
            completion(false)
        } else {
            completion(true)
        }
    }
    
    private let ocr = VisionOCR()
    
    func captureGhosttyAndProcess() async -> (items: [RecognizedTextItem], frame: CGRect, windowID: CGWindowID?, theme: AppTheme) {
        let defaultTheme = AppTheme(backgroundColor: .black, foregroundColor: .white)
        // print("DEBUG: captureGhostty() called")
        do {
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Let's only log if we find a window
            let allGhosttyWindows = content?.windows.filter { $0.owningApplication?.bundleIdentifier == "com.mitchellh.ghostty" } ?? []

            // Pick the window that is likely the active/visible one
            // SCK usually orders windows by Z-order (front to back)
            guard let window = allGhosttyWindows.first(where: { $0.isOnScreen && $0.frame.width > 100 }) else {
                return ([], .zero, nil, defaultTheme)
            }
            
            // print("DEBUG Capture: Using Window ID \(window.windowID), Frame \(window.frame)")
            let windowID = window.windowID
            
            // Find the screen the window is predominantly on to get its backing scale factor
            let windowCGRect = window.frame
            let targetScreen = NSScreen.screens.first { screen in
                let intersection = NSIntersectionRect(screen.frame, CoordinateTransform.sckFrameToAppKit(windowCGRect))
                return intersection.width * intersection.height > 0
            } ?? NSScreen.main ?? NSScreen.screens.first
            
            let scale = targetScreen?.backingScaleFactor ?? 2.0
            // print("DEBUG Capture: Using scale factor \(scale) for screen \(targetScreen?.localizedName ?? "unknown")")

            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width * scale)
            config.height = Int(window.frame.height * scale)
            
            // Ensure the window content scales to fill the balance of the capture buffer
            config.sourceRect = CGRect(origin: .zero, size: window.frame.size)
            config.destinationRect = CGRect(x: 0, y: 0, width: CGFloat(config.width), height: CGFloat(config.height))
            
            config.showsCursor = false
            config.ignoreShadowsDisplay = true // Critical: Exclude window shadows
            
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            
            // Phase 2: Run OCR
            let (items, theme) = try await ocr.recognizeText(in: image)
            
            return (items, window.frame, windowID, theme)
            
        } catch {
            print("DEBUG ERROR: Capture or OCR failed: \(error.localizedDescription)")
            return ([], .zero, nil, defaultTheme)
        }
    }
}
