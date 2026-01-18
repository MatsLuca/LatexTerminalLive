# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
