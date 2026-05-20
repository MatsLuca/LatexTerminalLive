# LatexTerminalLive

LatexTerminalLive is a sleek macOS utility that provides a live LaTeX overlay for your terminal. It specifically targets the **Ghostty** terminal, automatically detecting LaTeX expressions and rendering them in real-time as a high-quality overlay.

## ✨ Key Features

- **Live LaTeX Overlay**: Seamlessly renders mathematical expressions over your terminal window.
- **Ghostty Integration**: Native, silent integration with Ghostty via Accessibility API (high-speed text extraction).
- **Intelligent Recognition Engine**: Advanced heuristics for OCR correction, including:
    - **Smarter Flow-Text Guard**: Prevents normal text sentences containing math symbols (e.g. `\pm`, `\lambda`) from being implicitly wrapped and compressed as KaTeX.
    - **German Engineering Heuristics**: Advanced contextual subscripts (`neu`, `alt`, `ges`, `zul`, etc.) and physics labels (`kin`, `pot`, `tot`).
    - **Greek Case Consistency**: Automatically unifies Greek letters (e.g., `\Lambda` vs `\lambda`) based on context and majority usage.
    - **Fuzzy Command Repair**: Fixes common typos like `\alpda` -> `\alpha` or `\Zambda` -> `\lambda`.
    - **Physics & Math Optimization**: Robust row delimiter repair for matrices (`|`, `/`, `\` -> `\\`), German decimal separators, and malformed fractions.
    - **Precision Cleaning**: Automated repair for ellipses (`\dot` -> `\dots`), Z-prefix artifacts, and brace balancing.
- **Performance & Observability**:
    - **Tolerant Change-Detection (Fingerprinting)**: Custom pixel-level threshold guards ignore blinking terminal cursors and minor subpixel noise to keep the overlay absolutely static and flicker-free.
    - **Regex-Cached Cleaning**: Optimized LaTeX cleaning engine with cached patterns for minimal CPU impact.
    - **Centralized Configuration**: All app constants and timing logic unified in a single `Constants.swift`.
    - **Categorized Logging**: Clean, filtered debug output via the native macOS `OSLog` system.
- **Offline Rendering**: 100% offline-ready KaTeX execution using local bundle assets (no external CDN calls or internet connection required).
- **Global Hotkey**: Toggle or trigger capture with a customizable hotkey.
- **Modular Architecture**: Clean separation of concerns between Screen Capture, LaTeX Recognition, and Rendering.

## 🛠 Architecture

- **Capture**: Monitors and captures terminal content efficiently.
- **Recognition**: Intelligent parsing and cleaning of OCR-detected LaTeX.
- **Rendering**: Smooth, flicker-free rendering of LaTeX math.
- **App**: Native macOS experience with Menu Bar integration and Settings.
