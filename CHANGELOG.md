# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-01-21

### Added
- **Native AX Extraction**: Enabled direct Accessibility API integration for Ghostty. This allows for silent, non-intrusive text extraction without using the clipboard or causing auto-scrolling issues.
- **Buffer Synchronization Engine**: Completely rewrote the synchronization logic (`BufferSynthesizer`) to use a multi-anchor, case-insensitive, and cleaned matching strategy. This ensures logical 1:1 mapping between OCR positions and the exact text content from the terminal buffer, effectively eliminating OCR hallucinations (e.g., phantom bullets).
- **Hybrid Capture Mode**: The app now intelligently combines Vision OCR (for spatial positioning) with Accessibility Data (for semantic accuracy).

### Changed
- **Sandboxing Disabled**: Removed App Sandbox (`ENABLE_APP_SANDBOX = NO`) to permit required Accessibility interactions with external terminal processes.
- **Codebase Cleanup**: Removed unused legacy variables and aligned codebase with strict Swift compiler checks.

### Fixed
- **Ghostty Scrolling Bug**: Fixed the disruptive auto-scrolling caused by the previous clipboard-based fallback mechanism.
- **OCR Artifacts**: Implemented strict pre-cleaning for OCR queries (stripping bullets `•` and noise) before matching against the buffer.

## [0.3.5] - 2026-01-19

### Added
- **Physics Label Refinement**: Added robust support for kinetic and potential energy labels (`kin`, `pot`, `tot`). This specifically addresses the common OCR misinterpretation of `kin` as `\in` (element of).
- **Robust Subscript Handling**: Heuristics now support labels followed by commas or numbers (e.g., `$E_{kin,1}$`), ensuring complex physics indexes are correctly repaired while preserving their specific identifiers.

## [0.3.4] - 2026-01-18

### Added
- **ULTRATHINK: German Engineering Heuristics**: Advanced contextual repair for common subscripts and labels (`neu`, `alt`, `ges`, `zul`, etc.) inside `\text{...}` and subscripts. This specifically fixes physics-specific OCR artifacts like `\text{ \nu}` -> `\text{neu}`.

## [0.3.3] - 2026-01-18

### Fixed
- **German Label Repair**: Corrected OCR misinterpretation of German labels inside `\text` commands (e.g., `\text{ \nu}` -> `\text{neu}`).

## [0.3.2] - 2026-01-18

### Fixed
- **Fraction Transition Repair**: Added support for misread fraction argument separators (e.g., `){`, `}(`, `) {` -> `}{`).
- **Trailing Artifact Removal**: Improved logic to remove extra closing braces and whitespace at the end of math blocks.

## [0.3.1] - 2026-01-18

### Added
- **German Decimal Separator Heuristic**: Advanced correction for OCR artifacts around German decimal commas (e.g., `16f,}6` -> `16{,}6`).
- **`\text` Command Repair**: Intelligent formatting of `\text` commands, ensuring proper unit spacing and handling common misread characters.
- **`\frac` Structural Fixes**: Added robust repair logic for malformed fractions, including missing opening braces and incorrect argument transitions.
- **Aggressive Bracing Balancing**: Enhanced logic to remove trailing OCR artifacts like redundant closing braces.

## [0.3.0] - 2026-01-18

### Added
- **Fingerprinting Performance Optimization**: Added change detection to `ScreenCaptureManager` to skip redundant OCR processing when the screen hasn't changed.
- **Fuzzy LaTeX Command Correction**: New `FuzzyMatch` utility and logic in `LaTeXUtils` to automatically repair common OCR typos (e.g., `\alpda` -> `\alpha`).
- **Advanced OCR Heuristics**: Improved handling of matrix newlines (`||` -> `\\\\`) and persistent environment misreadings (e.g., `\endípmatrix`).
- **Clean Console**: Silenced verbose debug logs for a more streamlined developer experience.

### Changed
- Refactored `captureGhosttyAndProcess` to return a `CaptureResult` enum for better state handling.
- Updated hotkey and coordinate transform logging to be more conservative.

## [0.2.0] - 2026-01-11

### Added
- Modularized project structure: `App`, `Capture`, `Recognition`, `Rendering`, `Utilities`.
- `ScreenCaptureManager` for Ghostty terminal integration.
- Intelligent LaTeX recognition and cleaning heuristics.
- High-quality LaTeX overlay rendering.
- Global Hotkey support for manual triggers.
- Menu Bar icon and App Icon assets.
- App Sandbox configurations with necessary permissions.
- Initial `SettingsView` implementation.

### Changed
- Refactored core logic from boilerplate into modular components.
- Updated project configuration for code signing and Info.plist synchronization.

### Removed
- Legacy boilerplate files (`AppDelegate.swift`, `ContentView.swift` in root).
