# LatexTerminalLive

LatexTerminalLive is a sleek macOS utility that provides a live LaTeX overlay for your terminal. It specifically targets the **Ghostty** terminal, automatically detecting LaTeX expressions and rendering them in real-time as a high-quality overlay.

## ✨ Key Features

- **Live LaTeX Overlay**: Seamlessly renders mathematical expressions over your terminal window.
- **Ghostty Integration**: Native, silent integration with Ghostty via Accessibility API (no clipboard hacks).
- **Hybrid Capture Engine**: Combines **Vision OCR** (for precise positioning) with **Accessibility Data** (for 100% accurate text content), ensuring what you type is exactly what is rendered.
- **Drift-Free Synchronization**: Smart `BufferSynthesizer` aligns OCR data with the real terminal buffer, correcting OCR typos and formatting errors on the fly.
- **Resource-Saving Performance**: Intelligent fingerprinting detects display changes and skips OCR when the terminal is static.
- **Advanced LaTeX Recognition Engine**: Intelligent recognition with fuzzy matching to repair common OCR typos (`\alpda` -> `\alpha`), German decimal separators, malformed `\text` units, and `\frac` structural artifacts.
- **Global Hotkey**: Toggle or trigger capture with a customizable hotkey.
- **Modular Architecture**: Clean separation of concerns between Screen Capture, LaTeX Recognition, and Rendering.

## 🛠 Architecture

- **Capture**: Monitors and captures terminal content efficiently.
- **Recognition**: Intelligent parsing and cleaning of OCR-detected LaTeX.
- **Rendering**: Smooth, flicker-free rendering of LaTeX math.
- **App**: Native macOS experience with Menu Bar integration and Settings.
