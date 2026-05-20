import AppKit
import ScreenCaptureKit
import OSLog
import SwiftUI

enum CaptureResult {
    case success(items: [RecognizedTextItem], frame: CGRect, windowID: CGWindowID?, theme: AppTheme)
    case noChange
    case failure(CaptureError)
}

enum CaptureError: Error, CustomStringConvertible {
    case noWindowFound
    case captureError(String)
    case ocrError(String)

    var description: String {
        switch self {
        case .noWindowFound:
            return "No valid Ghostty window found"
        case .captureError(let message):
            return "Screen capture failed: \(message)"
        case .ocrError(let message):
            return "OCR processing failed: \(message)"
        }
    }
}

class ScreenCaptureManager: NSObject {
    private let logger = Logger(subsystem: "com.antigravity.LatexTerminalLive", category: "Capture")
    private var lastFingerprintPixels: [UInt8]?

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
    
    func captureGhosttyAndProcess(ignoreCache: Bool = false) async -> CaptureResult {
        DebugLog.capture("captureGhostty() called")
        do {
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Let's only log if we find a window
            let allGhosttyWindows = content?.windows.filter { $0.owningApplication?.bundleIdentifier == Constants.Terminal.bundleIdentifier } ?? []

            // Pick the window that is likely the active/visible one
            // SCK usually orders windows by Z-order (front to back)
            guard let window = allGhosttyWindows.first(where: { $0.isOnScreen && $0.frame.width > Constants.Geometry.minimumWindowWidth }) else {
                return .failure(.noWindowFound)
            }

            let windowID = window.windowID
            DebugLog.capture("Using Window ID \(windowID), Frame \(window.frame)")
            
            // Find the screen the window is predominantly on to get its backing scale factor
            let windowCGRect = window.frame
            let targetScreen = NSScreen.screens.first { screen in
                let intersection = NSIntersectionRect(screen.frame, CoordinateTransform.sckFrameToAppKit(windowCGRect))
                return intersection.width * intersection.height > 0
            } ?? NSScreen.main ?? NSScreen.screens.first
            
            let scale = targetScreen?.backingScaleFactor ?? 2.0
            DebugLog.capture("Using scale factor \(scale) for screen \(targetScreen?.localizedName ?? "unknown")")

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
            
            // Phase 1.5: Change Detection (Fingerprinting)
            let currentPixels = getFingerprintPixels(for: image)
            if !ignoreCache, let lastPixels = lastFingerprintPixels, !hasSignificantChange(old: lastPixels, new: currentPixels) {
                DebugLog.capture("No significant change detected, skipping OCR")
                return .noChange
            }
            lastFingerprintPixels = currentPixels
            
            // Phase 2: Run OCR
            let (items, theme) = try await ocr.recognizeText(in: image)
            
            return .success(items: items, frame: window.frame, windowID: windowID, theme: theme)

        } catch {
            let captureError = CaptureError.captureError(error.localizedDescription)
            DebugLog.capture("ERROR: \(captureError)")
            return .failure(captureError)
        }
    }
    
    /// Extracts grayscale pixel values (16x16) to be used for tolerant change detection.
    private func getFingerprintPixels(for image: CGImage) -> [UInt8] {
        let width = Constants.ImageProcessing.fingerprintWidth
        let height = Constants.ImageProcessing.fingerprintHeight
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return [] }
        
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return [] }
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height)
        
        var pixels = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            pixels[i] = buffer[i]
        }
        return pixels
    }
    
    /// Compares two fingerprints with tolerance for minor localized changes (e.g. blinking cursor).
    private func hasSignificantChange(old: [UInt8], new: [UInt8]) -> Bool {
        guard old.count == new.count else { return true }
        
        var diffCount = 0
        var totalAbsDiff = 0
        
        for i in 0..<old.count {
            let diff = abs(Int(old[i]) - Int(new[i]))
            if diff > 15 {
                diffCount += 1
            }
            totalAbsDiff += diff
        }
        
        let meanDiff = Double(totalAbsDiff) / Double(old.count)
        
        DebugLog.capture("Fingerprint change metrics: diffCount=\(diffCount), meanDiff=\(String(format: "%.2f", meanDiff))")
        
        // 1. Wenn sich nur extrem wenige Pixel signifikant geändert haben (z.B. <= 4 Pixel),
        // betrachten wir das als blinkenden Cursor oder lokales Rauschen.
        if diffCount <= 4 {
            return false
        }
        
        // 2. Wenn sich zwar viele Pixel minimal geändert haben, aber die durchschnittliche
        // Änderung extrem klein ist, ignorieren wir das (Rauschen/Subpixel-Rendern).
        if meanDiff < 1.5 {
            return false
        }
        
        return true
    }
}
