# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
