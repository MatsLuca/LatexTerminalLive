import AppKit
import ScreenCaptureKit

struct WindowFinder {
    static let ghosttyBundleID = "com.mitchellh.ghostty"
    
    static func findGhosttyWindow() async throws -> SCWindow? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Filter windows by bundle ID and ensure they belong to Ghostty
        return content.windows.first { window in
            guard let bundleID = window.owningApplication?.bundleIdentifier else { return false }
            return bundleID.lowercased() == ghosttyBundleID.lowercased()
        }
    }
}
