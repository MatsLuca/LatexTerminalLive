import Foundation

enum LaTeXUtils {
    private static var lastLoggedInput: String = ""
    private static var lastLogTime: Date = .distantPast

    /// Heuristically cleans common OCR errors in LaTeX strings.
    static func cleanOCRLaTeX(_ text: String) -> String {
        let shouldLog = text != lastLoggedInput || Date().timeIntervalSince(lastLogTime) > 2.0
        if shouldLog {
            print("[LaTeXUtils] Cleaning: \(text)")
            lastLoggedInput = text
            lastLogTime = Date()
        }
        var cleaned = text
        
        // 1. Fix commonly misread backslashes using Regex.
        // Replace |, /, l, I, 1 with \ if followed by a LaTeX keyword.
        let keywords = ["frac", "sqrt", "sum", "int", "alpha", "beta", "gamma", "delta", "theta", "phi", "pi", "infty", "approx", "cdot", "times", "left", "right", "begin", "end", "sin", "cos", "tan", "log", "ln", "Delta", "Sigma", "Omega", "text", "mathrm"]
        let keywordsPattern = keywords.joined(separator: "|")
        
        // Match [|/lI1] optionally followed by space, then a keyword
        let backslashRegex = try? NSRegularExpression(pattern: "[|/lI1]\\s*(?=\(keywordsPattern))", options: [])
        if let regex = backslashRegex {
            let nsString = cleaned as NSString
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "\\\\")
        }
        
        // 2. Fix OCR doubling letters or specific artifacts in common commands
        cleaned = cleaned.replacingOccurrences(of: "\\sqrtt", with: "\\sqrt")
        cleaned = cleaned.replacingOccurrences(of: "\\summm", with: "\\sum")
        cleaned = cleaned.replacingOccurrences(of: "\\inttt", with: "\\int")
        cleaned = cleaned.replacingOccurrences(of: "\\ffrac", with: "\\frac")
        
        // 3. Fix accidental spaces after backslash: "\ sum" -> "\sum"
        cleaned = cleaned.replacingOccurrences(of: "\\ ", with: "\\")
        
        // 4. Fix common keyword typos and character swaps
        // Use regex for \sqr to avoid replacing inside \sqrt (which would create \sqrtt)
        let sqrRegex = try? NSRegularExpression(pattern: "\\\\sqr(?![t])", options: [])
        if let regex = sqrRegex {
            let nsString = cleaned as NSString
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "\\\\sqrt")
        }

        let keywordFixes = [
            "\\rac": "\\frac",
            "\\summ": "\\sum",
            "\\infi": "\\infty",
            "\\Oelta": "\\Delta", // O seen as D
            "\\0elta": "\\Delta", // 0 seen as D
            "\\delta x": "\\Delta x", // In math/physics context, Delta is usually intended for differences
            "\\deltax": "\\Delta x"
        ]
        for (incorrect, correct) in keywordFixes {
            cleaned = cleaned.replacingOccurrences(of: incorrect, with: correct)
        }
        
        // 5. Advanced brace detection ('{' misread as 'ti', 'li', '!', etc.)
        let braceRequired = ["frac", "sqrt", "text", "mathrm", "mathbf", "Delta", "delta", "sum", "int"]
        for k in braceRequired {
            // Check for \keyword followed by artifacts: ti, li, !!, !, 1, i, l, { |
            let artifacts = ["ti", "li", "!!", "!", "1", "i", "l", "{|", "{l", "{i"]
            for a in artifacts {
                cleaned = cleaned.replacingOccurrences(of: "\\\(k)\(a)", with: "\\\(k){")
                cleaned = cleaned.replacingOccurrences(of: "\\\(k) \(a)", with: "\\\(k){")
            }
        }
        
        // 6. Secondary pass for remaining misread backslashes missed by lookahead
        // Explicitly fix common sequences like |Delta or /sqrt
        for k in keywords {
            cleaned = cleaned.replacingOccurrences(of: "|\(k)", with: "\\\(k)")
            cleaned = cleaned.replacingOccurrences(of: "/\(k)", with: "\\\(k)")
        }

        // 7. Ensure balanced braces
        let openBraces = cleaned.filter { $0 == "{" }.count
        let closeBraces = cleaned.filter { $0 == "}" }.count
        if openBraces > closeBraces {
            cleaned += String(repeating: "}", count: openBraces - closeBraces)
        }
        
        if shouldLog {
            print("[LaTeXUtils] Final:    \(cleaned)")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
