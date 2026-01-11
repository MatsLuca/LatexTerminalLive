import SwiftUI
import WebKit

struct MathView: NSViewRepresentable {
    let latex: String
    var fontSize: CGFloat
    var opacity: Double
    var color: Color

    private func cssColor(from color: Color) -> String {
        let nsColor = NSColor(color)
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return "rgb(\(r), \(g), \(b))"
    }
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let hexColor = cssColor(from: color)
        let stateKey = "\(latex)-\(fontSize)-\(opacity)-\(hexColor)"
        
        // Prevent redundant reloads if content is identical
        if context.coordinator.lastStateKey == stateKey {
            return
        }
        
        context.coordinator.lastStateKey = stateKey
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    padding-left: 4px;
                    display: flex;
                    justify-content: flex-start;
                    align-items: center;
                    height: 100vh;
                    overflow: visible;
                    background-color: transparent;
                    opacity: \(opacity);
                    color: \(hexColor);
                    font-size: \(fontSize)px;
                }
                .katex-display { margin: 0; }
                .katex { white-space: nowrap; }
                
                /* Graceful fallback style */
                .fallback {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-style: italic;
                    font-weight: 300;
                    opacity: 0.6;
                    white-space: nowrap;
                    font-size: 0.9em;
                }
            </style>
        </head>
        <body>
            <div id="math" style="padding: 0px; display: inline-block;"></div>
            <script>
                const rawLatex = "\(latex.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "$", with: ""))";
                const mathContainer = document.getElementById('math');
                
                try {
                    mathContainer.innerHTML = katex.renderToString(rawLatex, {
                        displayMode: false,
                        throwOnError: true // We want to catch the error
                    });
                } catch (e) {
                    // Fail gracefully: show original text in fallback style
                    mathContainer.innerHTML = `<span class="fallback">${rawLatex}</span>`;
                    console.log("KaTeX Error:", e.message);
                }
            </script>
        </body>
        </html>
        """
        nsView.loadHTMLString(html, baseURL: nil)
    }
    
    class Coordinator {
        var lastStateKey: String = ""
    }
}
