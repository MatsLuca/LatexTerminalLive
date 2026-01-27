import Foundation
import OSLog

/// Unified debug logging system for development builds.
/// Enable logging by setting DEBUG_MODE=1 environment variable in Xcode scheme.
enum DebugLog {

    /// Whether debug logging is enabled (controlled by DEBUG_MODE env var)
    static let enabled = ProcessInfo.processInfo.environment["DEBUG_MODE"] == "1"

    /// Standard OSLog logger for the app
    private static let logger = Logger(subsystem: Constants.App.name, category: "Debug")

    /// Log a debug message (only outputs if DEBUG_MODE=1)
    static func log(_ message: String, category: String = "General") {
        guard enabled else { return }
        logger.debug("[\(category)] \(message)")
    }

    /// Log to specific category
    static func capture(_ message: String) {
        log(message, category: "Capture")
    }

    static func ocr(_ message: String) {
        log(message, category: "OCR")
    }

    static func latex(_ message: String) {
        log(message, category: "LaTeX")
    }

    static func hotkey(_ message: String) {
        log(message, category: "Hotkey")
    }

    static func automation(_ message: String) {
        log(message, category: "Automation")
    }

    static func coordinates(_ message: String) {
        log(message, category: "Coordinates")
    }
}
