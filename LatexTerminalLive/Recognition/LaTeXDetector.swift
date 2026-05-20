import Foundation

enum LaTeXDelimiterType {
    case dollar         // $...$
    case doubleDollar   // $$...$$
    case bracket        // \[...\]
    case parenthesis    // \(...\)
    
    var start: String {
        switch self {
        case .dollar: return "$"
        case .doubleDollar: return "$$"
        case .bracket: return "\\["
        case .parenthesis: return "\\("
        }
    }
    
    var end: String {
        switch self {
        case .dollar: return "$"
        case .doubleDollar: return "$$"
        case .bracket: return "\\]"
        case .parenthesis: return "\\)"
        }
    }
}

struct LaTeXSegment: Identifiable {
    let id = UUID()
    let text: String
    let isMath: Bool
    let originalRange: NSRange
    
    init(text: String, isMath: Bool, originalRange: NSRange? = nil) {
        self.text = text
        self.isMath = isMath
        self.originalRange = originalRange ?? NSRange(location: 0, length: (text as NSString).length)
    }
}

class LaTeXDetector {
    
    /// Detects math patterns and returns true if the fragment contains any LaTeX.
    func containsLaTeX(_ text: String) -> Bool {
        return text.contains("$") || text.contains("\\[") || text.contains("\\(")
    }
    
    /// Splits a string into math and non-math segments using robust delimiter matching.
    func segmentText(_ text: String) -> [LaTeXSegment] {
        var segments: [LaTeXSegment] = []
        
        // Prüfen, ob wir implizites LaTeX vorliegen haben (keine Delimiter, aber hochgradig spezifische mathematische Kommandos oder Muster)
        let hasDelimiters = text.contains("$") || text.contains("\\[") || text.contains("\\(")
        let hasHighlySpecificCommand = LaTeXUtils.containsHighlySpecificLaTeXCommand(text)
        let hasMathPatterns = text.contains("_{") || text.contains("^{")
        
        var shouldImplicitlyPatch = !hasDelimiters && (hasHighlySpecificCommand || hasMathPatterns)
        
        // Guard: Prevent normal sentences that happen to mention a LaTeX command (e.g. in explanations)
        // from being implicitly patched. If there is no colon, a math expression should be relatively compact
        // or contain math operators (=, +, -, etc.).
        if shouldImplicitlyPatch {
            let textToVerify: String
            if let colonIndex = text.firstIndex(of: ":") {
                textToVerify = String(text[text.index(after: colonIndex)...])
            } else {
                textToVerify = text
            }
            
            if isFlowText(textToVerify) {
                shouldImplicitlyPatch = false
            } else if !text.contains(":") {
                let spaceCount = text.filter { $0.isWhitespace }.count
                let hasMathOperators = text.contains("=") || text.contains("+") || text.contains("-") || text.contains("*") || text.contains("/") || text.contains("<") || text.contains(">")
                
                if spaceCount > 3 && !hasMathOperators {
                    shouldImplicitlyPatch = false
                }
            }
        }
        
        if shouldImplicitlyPatch {
            // Heuristik: Formel meistens nach Doppelpunkt (z.B. "Dezimalzahlen (Deutsch): p = 16,6 \pm 0,2 bar")
            if let colonIndex = text.firstIndex(of: ":") {
                let nsText = text as NSString
                let colonOffset = text.distance(from: text.startIndex, to: colonIndex)
                
                let prefixText = String(text[..<colonIndex]) + ":"
                let suffixText = String(text[text.index(after: colonIndex)...])
                
                let prefixRange = NSRange(location: 0, length: colonOffset + 1)
                let suffixRange = NSRange(location: colonOffset + 1, length: nsText.length - (colonOffset + 1))
                
                // Wir fügen das Nicht-Math-Präfix hinzu
                segments.append(LaTeXSegment(text: prefixText, isMath: false, originalRange: prefixRange))
                
                // Und das Math-Suffix (mit Delimitern geflickt für KaTeX/Detector, aber originalRange verweist auf das echte Suffix)
                let trimmedSuffix = suffixText.trimmingCharacters(in: .whitespacesAndNewlines)
                segments.append(LaTeXSegment(text: "$\(trimmedSuffix)$", isMath: true, originalRange: suffixRange))
                
                return segments
            } else {
                // Fallback: Gesamten Text umschließen
                let nsText = text as NSString
                let fullRange = NSRange(location: 0, length: nsText.length)
                segments.append(LaTeXSegment(text: "$\(text.trimmingCharacters(in: .whitespacesAndNewlines))$", isMath: true, originalRange: fullRange))
                return segments
            }
        }
        
        let nsString = text as NSString
        var messageIndex = 0
        let length = nsString.length
        
        while messageIndex < length {
            // Find the earliest valid start delimiter
            guard let match = findNextPotentialStart(in: text, startIndex: messageIndex) else {
                // No more math, add remaining text
                let remaining = nsString.substring(from: messageIndex)
                if !remaining.isEmpty {
                    let range = NSRange(location: messageIndex, length: remaining.count)
                    segments.append(LaTeXSegment(text: remaining, isMath: false, originalRange: range))
                }
                break
            }
            
            // Add non-math text before the match
            if match.startIndex > messageIndex {
                let prefix = nsString.substring(with: NSRange(location: messageIndex, length: match.startIndex - messageIndex))
                let range = NSRange(location: messageIndex, length: prefix.count)
                segments.append(LaTeXSegment(text: prefix, isMath: false, originalRange: range))
            }
            
            // Try to find the matching closer
            if let endIndex = findClosingDelimiter(type: match.type, in: text, afterIndex: match.contentStartIndex) {
                // Found a complete math block
                let totalLength = endIndex - match.startIndex
                let mathBlock = nsString.substring(with: NSRange(location: match.startIndex, length: totalLength))
                let range = NSRange(location: match.startIndex, length: totalLength)
                segments.append(LaTeXSegment(text: mathBlock, isMath: true, originalRange: range))
                
                messageIndex = endIndex
            } else {
                // Kein schließender Delimiter gefunden!
                // Prüfen, ob der verbleibende Text ab match.startIndex bekannte LaTeX-Kommandos oder mathematische Muster enthält.
                let remainingText = nsString.substring(from: match.startIndex)
                if LaTeXUtils.containsKnownLaTeXCommand(remainingText) || remainingText.contains("_{") || remainingText.contains("det(") {
                    // Extrem tolerantes Flicken: Wir deklarieren den gesamten verbleibenden Text als Math-Segment
                    // und hängen virtuell den schließenden Delimiter an, damit KaTeX es rendert.
                    let mathBlock = remainingText + match.type.end
                    let range = NSRange(location: match.startIndex, length: remainingText.count)
                    segments.append(LaTeXSegment(text: mathBlock, isMath: true, originalRange: range))
                    break // Da wir den gesamten Rest verbraucht haben
                } else {
                    // No closer found and no math context, treat start delimiter as literal text
                    let delimiterLen = match.type.start.count
                    let literalText = nsString.substring(with: NSRange(location: match.startIndex, length: delimiterLen))
                    let range = NSRange(location: match.startIndex, length: delimiterLen)
                    segments.append(LaTeXSegment(text: literalText, isMath: false, originalRange: range))
                    messageIndex = match.startIndex + delimiterLen
                }
            }
        }
        
        // Merge adjacent non-math segments (optimization)
        return mergeAdjacentSegments(segments)
    }
    
    // MARK: - Helper Types & Methods
    
    private struct StartMatch {
        let type: LaTeXDelimiterType
        let startIndex: Int
        let contentStartIndex: Int // Index where content begins (after delimiter)
    }
    
    private func findNextPotentialStart(in text: String, startIndex: Int) -> StartMatch? {
        let nsString = text as NSString
        let validRange = NSRange(location: startIndex, length: nsString.length - startIndex)
        
        var bestMatch: StartMatch? = nil
        let delimiters: [LaTeXDelimiterType] = [.doubleDollar, .bracket, .parenthesis, .dollar]
        
        for type in delimiters {
            var searchRange = validRange
            while searchRange.length > 0 {
                let foundRange = nsString.range(of: type.start, options: [], range: searchRange)
                if foundRange.location == NSNotFound {
                    break
                }
                
                // Check if escaped (e.g. "\$")
                if isEscaped(index: foundRange.location, in: text) {
                    let newLocation = foundRange.location + foundRange.length
                    searchRange = NSRange(location: newLocation, length: nsString.length - newLocation)
                    continue
                }
                
                // Special case: If we found '$', check if it is actually part of '$$'
                if type == .dollar {
                    if foundRange.location + 1 < nsString.length && nsString.substring(with: NSRange(location: foundRange.location, length: 2)) == "$$" {
                        let newLocation = foundRange.location + 2
                        searchRange = NSRange(location: newLocation, length: nsString.length - newLocation)
                        continue
                    }
                }
                
                let candidate = StartMatch(type: type, startIndex: foundRange.location, contentStartIndex: foundRange.location + foundRange.length)
                
                if bestMatch == nil || candidate.startIndex < bestMatch!.startIndex {
                    bestMatch = candidate
                }
                break
            }
        }
        
        return bestMatch
    }
    
    private func findClosingDelimiter(type: LaTeXDelimiterType, in text: String, afterIndex: Int) -> Int? {
        let nsString = text as NSString
        var searchIndex = afterIndex
        
        while searchIndex < nsString.length {
            let searchRange = NSRange(location: searchIndex, length: nsString.length - searchIndex)
            let foundRange = nsString.range(of: type.end, options: [], range: searchRange)
            
            if foundRange.location == NSNotFound {
                return nil
            }
            
            // Check escaping
            if isEscaped(index: foundRange.location, in: text) {
                searchIndex = foundRange.location + foundRange.length
                continue
            }
            
            return foundRange.location + foundRange.length
        }
        
        return nil
    }
    
    private func isEscaped(index: Int, in text: String) -> Bool {
        guard index > 0 else { return false }
        let nsString = text as NSString
        var backslashCount = 0
        var i = index - 1
        while i >= 0 {
            if nsString.substring(with: NSRange(location: i, length: 1)) == "\\" {
                backslashCount += 1
                i -= 1
            } else {
                break
            }
        }
        return backslashCount % 2 != 0
    }
    
    private func mergeAdjacentSegments(_ segments: [LaTeXSegment]) -> [LaTeXSegment] {
        var merged: [LaTeXSegment] = []
        for segment in segments {
            if let last = merged.last, !last.isMath, !segment.isMath {
                let combinedRange = NSRange(
                    location: last.originalRange.location,
                    length: last.originalRange.length + segment.originalRange.length
                )
                let newSegment = LaTeXSegment(text: last.text + segment.text, isMath: false, originalRange: combinedRange)
                merged.removeLast()
                merged.append(newSegment)
            } else {
                merged.append(segment)
            }
        }
        return merged
    }
    
    private func isFlowText(_ text: String) -> Bool {
        // Trenne den Text in reine Buchstaben-Sequenzen
        let words = text.components(separatedBy: CharacterSet.letters.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var flowTextWordCount = 0
        
        let excludedWords: Set<String> = [
            // Bekannte LaTeX-Befehle und Funktionen
            "frac", "sqrt", "sum", "int", "prod", "coprod",
            "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu", "nu", "xi", "omicron", "pi", "rho", "sigma", "tau", "upsilon", "phi", "chi", "psi", "omega",
            "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi", "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega",
            "infty", "approx", "cdot", "times", "div", "pm", "mp", "neq", "leq", "geq", "sim", "equiv",
            "partial", "nabla", "forall", "exists", "notin", "subset", "subseteq", "cup", "cap", "emptyset",
            "sin", "cos", "tan", "csc", "sec", "cot", "log", "ln", "exp", "lim", "sup", "inf", "max", "min", "det",
            "text", "mathrm", "mathbf", "mathit", "mathcal", "mathbb",
            
            // Gängige physikalische Einheiten und Bezeichner (Deutsch/Englisch)
            "volt", "watt", "ampere", "kelvin", "joule", "pascal", "bar", "grad", "celsius", "meter", "gramm", "kilo", "liter", "hertz", "newton", "tesla", "henry", "farad",
            "const", "constant", "true", "false", "step", "null", "void", "rad", "deg", "var", "cov", "std", "sgn", "dim", "ker", "img", "pdf", "cdf"
        ]
        
        for word in words {
            let lowerWord = word.lowercased()
            
            // Ein Fließtext-Wort muss:
            // 1. Mindestens 3 Zeichen lang sein (um kurze Wörter wie "ist", "ein", "und", "für", "wie" zu erfassen)
            // 2. Nicht in der Ausschlussliste von mathematischen/physikalischen Begriffen liegen
            if word.count >= 3 && !excludedWords.contains(lowerWord) {
                flowTextWordCount += 1
            }
        }
        
        // Wenn wir mehr als 1 typisches Fließtext-Wort finden (also mindestens 2), deklarieren wir es als Fließtext.
        return flowTextWordCount > 1
    }
}
