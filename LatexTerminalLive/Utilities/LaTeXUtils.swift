import Foundation

enum LaTeXUtils {
    private static var lastLoggedInput: String = ""
    private static var lastLogTime: Date = .distantPast

    // Expanded dictionary of common LaTeX math commands
    private static let knownCommands: [String] = [
        "frac", "sqrt", "sum", "int", "prod", "coprod",
        "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu", "nu", "xi", "omicron", "pi", "rho", "sigma", "tau", "upsilon", "phi", "chi", "psi", "omega",
        "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi", "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega",
        "infty", "approx", "cdot", "times", "div", "pm", "mp", "neq", "leq", "geq", "sim", "equiv",
        "partial", "nabla", "forall", "exists", "in", "notin", "subset", "subseteq", "cup", "cap", "nothing", "emptyset",
        "rightarrow", "Rightarrow", "leftarrow", "Leftarrow", "leftrightarrow", "Leftrightarrow", "to", "mapsto", "implies", "iff", "impliedby",
        "left", "right", "begin", "end",
        "sin", "cos", "tan", "csc", "sec", "cot", "log", "ln", "exp", "lim", "sup", "inf", "max", "min",
        "text", "mathrm", "mathbf", "mathit", "mathcal", "mathbb",
        "hat", "bar", "vec", "dot", "ddot", "tilde", "ule", "underline", "overline"
    ]

    /// Heuristically cleans common OCR errors in LaTeX strings.
    static func cleanOCRLaTeX(_ text: String) -> String {
        let shouldLog = text != lastLoggedInput || Date().timeIntervalSince(lastLogTime) > 2.0
        if shouldLog {
            // print("[LaTeXUtils] Cleaning: \(text)")
            lastLoggedInput = text
            lastLogTime = Date()
        }
        var cleaned = text
        
        // 1. Initial heuristic fixes (Fast Pass)
        // Fix accidental spaces after backslash: "\ sum" -> "\sum"
        cleaned = cleaned.replacingOccurrences(of: "\\ ", with: "\\")
        
        // Fix doubled letters from OCR stuttering (e.g. \sqrtt)
        cleaned = cleaned.replacingOccurrences(of: "\\sqrtt", with: "\\sqrt")
        cleaned = cleaned.replacingOccurrences(of: "\\summm", with: "\\sum")
        cleaned = cleaned.replacingOccurrences(of: "\\inttt", with: "\\int")
        cleaned = cleaned.replacingOccurrences(of: "\\ffrac", with: "\\frac")
        
        // --- NEW HEURISTICS (User Feedback) ---
        
        // A. Brute Force Fixes for Persistent Errors
        // These specific strings were reported by the user as persistent issues.
        // We handle them explicitly to guarantee correction regarding of regex complexity.
        cleaned = cleaned.replacingOccurrences(of: "\\endípmatrix", with: "\\end{pmatrix}")
        cleaned = cleaned.replacingOccurrences(of: "\\begin{pmatrix)", with: "\\begin{pmatrix}")
        cleaned = cleaned.replacingOccurrences(of: "\\vec}", with: "\\vec{u}")
        
        // B. Fix Double Pipe as Newline in Matrices: "||" -> "\\"
        // This is a very common OCR misinterpretation of the double backslash.
        cleaned = cleaned.replacingOccurrences(of: "||", with: "\\\\")
        
        // C. General Environment Fix (Regex)
        // Catches variations like \end{ípmatrix}, \end[pmatrix], etc.
        let environments = ["pmatrix", "bmatrix", "vmatrix", "matrix", "array", "align", "equation", "cases"]
        let envPattern = environments.joined(separator: "|")
        // Regex: \\(begin|end)\s*[íli{(\[]*\s*(env)\s*[)}\]í]*
        if let looseEnvRegex = try? NSRegularExpression(pattern: "\\\\(begin|end)\\s*[íli{(\\[]*\\s*(\(envPattern))\\s*[\\)}\\]í]*", options: .caseInsensitive) {
            let nsString = cleaned as NSString
            let range = NSRange(location: 0, length: nsString.length)
            cleaned = looseEnvRegex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "\\\\$1{$2}")
        }
        
        // -------------------------------------
        
        // 2. Fuzzy Command Correction
        // Detects words that look like commands but have typos or wrong prefixes.
        cleaned = correctFuzzyCommands(cleaned)
        
        // 3. Advanced brace detection ('{' misread as 'ti', 'li', '!', etc.)
        // This is context-aware based on the command preceding it.
        let braceRequired = ["frac", "sqrt", "text", "mathrm", "mathbf", "Delta", "delta", "sum", "int"]
        for k in braceRequired {
            // Check for \keyword followed by artifacts: ti, li, !!, !, 1, i, l, { |
            let artifacts = ["ti", "li", "!!", "!", "1", "i", "l", "{|", "{l", "{i"]
            for a in artifacts {
                cleaned = cleaned.replacingOccurrences(of: "\\\(k)\(a)", with: "\\\(k){")
                cleaned = cleaned.replacingOccurrences(of: "\\\(k) \(a)", with: "\\\(k){")
            }
        }
        
        // 4. Ensure balanced braces (Simple heuristic)
        let openBraces = cleaned.filter { $0 == "{" }.count
        let closeBraces = cleaned.filter { $0 == "}" }.count
        if openBraces > closeBraces {
            cleaned += String(repeating: "}", count: openBraces - closeBraces)
        }
        
        if shouldLog {
            // print("[LaTeXUtils] Final:    \(cleaned)")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Scans the text for potential LaTeX commands and fuzzy-corrects them.
    private static func correctFuzzyCommands(_ text: String) -> String {
        let nsString = text as NSString
        let length = nsString.length
        
        // Regex to find "words" that might be commands.
        // We look for a pattern that starts with a potential backslash (or error) followed by letters.
        // Potential backslashes: \, |, /, l, I, 1
        // But also, simply words that match a command very closely even without a prefix, 
        // IF they are long enough (avoids changing "sin" variable to "\sin" too aggressively, but in math block \sin is preferred).
        
        // Regex: ([\\]|[|/lI1])?([a-zA-Z]{3,})
        // Matches an optional prefix followed by at least 3 letters.
        guard let regex = try? NSRegularExpression(pattern: "([\\\\]|[|/lI1])?([a-zA-Z]{3,})", options: []) else { return text }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: length))
        
        var mutableText = text
        let mutableNsString = NSMutableString(string: mutableText)
        
        for match in matches.reversed() {
            let fullRange = match.range
            let prefixRange = match.range(at: 1)
            let wordRange = match.range(at: 2)
            
            let hasPrefix = prefixRange.location != NSNotFound
            var prefix = ""
            if hasPrefix {
                prefix = nsString.substring(with: prefixRange)
            }
            let word = nsString.substring(with: wordRange)
            
            // 1. Exact match with correct prefix, skip
            if hasPrefix && prefix == "\\" && knownCommands.contains(word) {
                continue
            }
            
            // 2. Determine fuzzy strategy
            // If prefix exists, we are confident it's a command -> allow standard looseness.
            // If NO prefix, we must be strict to avoid false positives (e.g. "Start" -> "\star").
            
            var maxDist: Int = 1
            if hasPrefix {
                // With prefix, allow distance 2 for longer words
                maxDist = word.count <= 4 ? 1 : 2
            } else {
                // Without prefix, ALWAYS strict (dist 1).
                // "alpba" (5) vs "alpha" (5) -> dist 1. OK.
                // "super" (5) vs "sup" (3) -> dist 2. REJECTED.
                maxDist = 1
            }
            
            if let bestMatch = FuzzyMatch.findBestMatch(for: word, in: knownCommands, maxDistance: maxDist) {
                // 3. Additional Guard for "No Prefix" case: Case Sensitivity Check
                // If input starts with Uppercase, and match starts with Lowercase, likely a false positive.
                // Example: "Start" (Upper) -> "star" (Lower). Skip.
                if !hasPrefix {
                    let wordFirst = word.first
                    let matchFirst = bestMatch.first
                    if let wf = wordFirst, let mf = matchFirst {
                        if wf.isUppercase && mf.isLowercase {
                            continue
                        }
                    }
                }
                
                let replacement = "\\" + bestMatch
                let originalContent = nsString.substring(with: fullRange)
                if originalContent != replacement {
                    mutableNsString.replaceCharacters(in: fullRange, with: replacement)
                }
            }
        }
        
        return String(mutableNsString)
    }
}
