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
}

class LaTeXDetector {
    
    /// Detects math patterns and returns true if the fragment contains any LaTeX.
    func containsLaTeX(_ text: String) -> Bool {
        // Quick check for any potential delimiter
        return text.contains("$") || text.contains("\\[") || text.contains("\\(")
    }
    
    /// Splits a string into math and non-math segments using robust delimiter matching.
    func segmentText(_ text: String) -> [LaTeXSegment] {
        var segments: [LaTeXSegment] = []
        let nsString = text as NSString
        var messageIndex = 0
        let length = nsString.length
        
        while messageIndex < length {
            // Find the earliest valid start delimiter
            guard let match = findNextPotentialStart(in: text, startIndex: messageIndex) else {
                // No more math, add remaining text
                let remaining = nsString.substring(from: messageIndex)
                if !remaining.isEmpty {
                    segments.append(LaTeXSegment(text: remaining, isMath: false))
                }
                break
            }
            
            // Add non-math text before the match
            if match.startIndex > messageIndex {
                let prefix = nsString.substring(with: NSRange(location: messageIndex, length: match.startIndex - messageIndex))
                segments.append(LaTeXSegment(text: prefix, isMath: false))
            }
            
            // Try to find the matching closer
            if let endIndex = findClosingDelimiter(type: match.type, in: text, afterIndex: match.contentStartIndex) {
                // Found a complete math block
                // Include the delimiters in the math segment so KaTeX renders it (or strip if KaTeX expects plain content, 
                // but usually preserving structure is safer, though MathView removes $ signals. 
                // Let's pass the raw content including delimiters, and MathView can handle cleaning or we tell KaTeX to render.
                // CURRENT MATHVIEW logic strips '$' manually. We should probably update MathView to handle other delimiters too.
                // For now, let's extract the full block.
                
                let totalLength = endIndex - match.startIndex
                let mathBlock = nsString.substring(with: NSRange(location: match.startIndex, length: totalLength))
                segments.append(LaTeXSegment(text: mathBlock, isMath: true))
                
                messageIndex = endIndex
            } else {
                // No closer found, treat start delimiter as literal text
                // Advance just past the start delimiter to avoid infinite loop
                let delimiterLen = match.type.start.count
                let literalText = nsString.substring(with: NSRange(location: match.startIndex, length: delimiterLen))
                segments.append(LaTeXSegment(text: literalText, isMath: false))
                messageIndex = match.startIndex + delimiterLen
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
        
        // We look for all delimiters and pick the earliest one.
        // Priority: $$ > $ (longest match first for greedy starts), but position matters most.
        // Actually, if we see "$$", it is definitely DoubleDollar, not two Dollars.
        // If we see "$...", it is Dollar.
        
        var bestMatch: StartMatch? = nil
        
        let delimiters: [LaTeXDelimiterType] = [.doubleDollar, .bracket, .parenthesis, .dollar]
        
        for type in delimiters {
            let pattern = NSRegularExpression.escapedPattern(for: type.start)
            // We implement manual search to handle escaping correctly? 
            // Regex is easier for "find next occurrence".
            // Let's use simple search but check for escaping.
            
            var searchRange = validRange
            while searchRange.length > 0 {
                let foundRange = nsString.range(of: type.start, options: [], range: searchRange)
                if foundRange.location == NSNotFound {
                    break
                }
                
                // Check if escaped (e.g. "\$")
                if isEscaped(index: foundRange.location, in: text) {
                    // It is escaped, so finding the next one
                    let newLocation = foundRange.location + foundRange.length
                    searchRange = NSRange(location: newLocation, length: nsString.length - newLocation)
                    continue
                }
                
                // It is a candidate
                // Special case: If we found '$', check if it is actually part of '$$'
                if type == .dollar {
                    // If the character immediately following is '$', then this is a '$$' start, 
                    // which should have been caught by .doubleDollar loop.
                    // However, we process bestMatch by *index*.
                    if foundRange.location + 1 < nsString.length && nsString.substring(with: NSRange(location: foundRange.location, length: 2)) == "$$" {
                        // This is a double dollar. Ignore this match in the .dollar loop.
                        // The .doubleDollar loop will (or has) catch it.
                        // We just break this inner while since we want to find a single dollar, and this spot is occupied.
                        // Actually, we should keep searching for a single dollar later in the string.
                        let newLocation = foundRange.location + 2
                        searchRange = NSRange(location: newLocation, length: nsString.length - newLocation)
                        continue
                    }
                }
                
                // If we are here, we found a valid start for this type.
                let candidate = StartMatch(type: type, startIndex: foundRange.location, contentStartIndex: foundRange.location + foundRange.length)
                
                // If this is earlier than current best match, take it.
                if bestMatch == nil || candidate.startIndex < bestMatch!.startIndex {
                    bestMatch = candidate
                }
                break // Found the first valid one of this type, move to next type
            }
        }
        
        return bestMatch
    }
    
    private func findClosingDelimiter(type: LaTeXDelimiterType, in text: String, afterIndex: Int) -> Int? {
        let nsString = text as NSString
        // Search for the end delimiter starting after the start delimiter
        // We must skip escaped ones.
        
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
            
            // Found it! return the index AFTER the delimiter (exclusive end index)
            return foundRange.location + foundRange.length
        }
        
        return nil
    }
    
    private func isEscaped(index: Int, in text: String) -> Bool {
        guard index > 0 else { return false }
        let nsString = text as NSString
        // Check number of backslashes before index
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
        // Odd number of backslashes means the character at `index` is escaped
        return backslashCount % 2 != 0
    }
    
    private func mergeAdjacentSegments(_ segments: [LaTeXSegment]) -> [LaTeXSegment] {
        var merged: [LaTeXSegment] = []
        for segment in segments {
            if let last = merged.last, !last.isMath, !segment.isMath {
                // Merge two non-math segments
                let newSegment = LaTeXSegment(text: last.text + segment.text, isMath: false)
                merged.removeLast()
                merged.append(newSegment)
            } else {
                merged.append(segment)
            }
        }
        return merged
    }
}
