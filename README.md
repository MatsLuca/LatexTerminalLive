# LatexTerminalLive

LatexTerminalLive is a sleek macOS utility that provides a live LaTeX overlay for your terminal. It specifically targets the **Ghostty** terminal, automatically detecting LaTeX expressions and rendering them in real-time as a high-quality overlay.

## ✨ Key Features

- **Live LaTeX Overlay**: Seamlessly renders mathematical expressions over your terminal window.
- **Ghostty Integration**: Optimized for the Ghostty terminal experience.
- **Global Hotkey**: Toggle or trigger capture with a customizable hotkey.
- **Modular Architecture**: Clean separation of concerns between Screen Capture, LaTeX Recognition, and Rendering.
- **App Sandbox**: Security-first approach with minimal required permissions.

## 🛠 Architecture

- **Capture**: Monitors and captures terminal content efficiently.
- **Recognition**: Intelligent parsing and cleaning of OCR-detected LaTeX.
- **Rendering**: Smooth, flicker-free rendering of LaTeX math.
- **App**: Native macOS experience with Menu Bar integration and Settings.
