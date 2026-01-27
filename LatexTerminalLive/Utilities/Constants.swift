import Foundation
import CoreGraphics

enum Constants {

    // MARK: - Application Info

    enum App {
        static let version = "1.0"
        static let name = "LatexTerminalLive"
    }

    // MARK: - Target Terminal

    enum Terminal {
        static let bundleIdentifier = "com.mitchellh.ghostty"
        static let displayName = "Ghostty"
    }

    // MARK: - Timing & Performance

    enum Timing {
        /// Interval for window position tracking (seconds)
        static let windowTrackingInterval: TimeInterval = 0.1

        /// Default interval for Live Mode auto-updates (seconds)
        static let defaultLiveModeInterval: TimeInterval = 2.0

        /// Minimum allowed Live Mode interval (seconds)
        static let minimumLiveModeInterval: TimeInterval = 0.5

        /// Maximum allowed Live Mode interval (seconds)
        static let maximumLiveModeInterval: TimeInterval = 60.0

        /// Debounce time for logging duplicate OCR results (seconds)
        static let logDebounceInterval: TimeInterval = 3.0
    }

    // MARK: - Coordinate & Geometry

    enum Geometry {
        /// Tolerance for comparing normalized coordinates (0.0-1.0 scale)
        static let coordinateTolerance: CGFloat = 0.002

        /// Minimum window width to consider for capture
        static let minimumWindowWidth: CGFloat = 100.0
    }

    // MARK: - Image Processing

    enum ImageProcessing {
        /// Fingerprint thumbnail width for change detection
        static let fingerprintWidth = 16

        /// Fingerprint thumbnail height for change detection
        static let fingerprintHeight = 16
    }

    // MARK: - OCR Settings

    enum OCR {
        /// Vision framework recognition level
        static let recognitionLevel = "accurate" // VNRequestTextRecognitionLevel.accurate

        /// Whether to use language correction
        static let usesLanguageCorrection = false
    }

    // MARK: - Hotkeys

    enum Hotkeys {
        /// Default hotkey: Cmd+Shift+L
        static let defaultTriggerKey: UInt16 = 37 // 'L' key code
        static let defaultTriggerModifiers: UInt = 0x120108 // Cmd+Shift

        /// Settings hotkey: Cmd+,
        static let settingsKey: UInt16 = 43 // ',' key code
        static let settingsModifiers: UInt = 0x100108 // Cmd
    }

    // MARK: - UI & Animation

    enum UI {
        /// Overlay update animation duration
        static let overlayAnimationDuration: TimeInterval = 0.2

        /// Copy feedback animation duration
        static let copyFeedbackDuration: TimeInterval = 0.2

        /// Copy feedback auto-hide delay
        static let copyFeedbackHideDelay: TimeInterval = 1.5

        /// Copy feedback fade-out duration
        static let copyFeedbackFadeOutDuration: TimeInterval = 0.3

        /// Menu bar icon size
        static let menuBarIconSize = CGSize(width: 18, height: 18)
    }

    // MARK: - Validation Ranges

    enum Validation {
        /// Valid range for Live Mode update interval
        static let liveModeIntervalRange = minimumLiveModeInterval...maximumLiveModeInterval

        private static let minimumLiveModeInterval = Timing.minimumLiveModeInterval
        private static let maximumLiveModeInterval = Timing.maximumLiveModeInterval
    }
}
