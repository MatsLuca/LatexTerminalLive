import Foundation
import CoreGraphics
import OSLog

class BufferSynthesizer {
    private let detector = LaTeXDetector()
    private let logger = Logger(subsystem: "com.antigravity.LatexTerminalLive", category: "BufferSynthesizer")
    
    /// Synthesizes OCR items with the ground-truth buffer using Strict Slot-Filling.
    /// Maps the N-th OCR item to the N-th Buffer Formula entirely by sequence, ignoring OCR text content.
    func synthesize(ocrItems: [RecognizedTextItem], buffer: String) -> [RecognizedTextItem] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Clean Buffer and Extract "Truth" Sequence
        let cleanBuffer = stripANSI(buffer)
        
        // Extract all math segments from the buffer (The "Truth")
        // We filter for .isMath to get the exact sequence of formulas
        let truthSegments = detector.segmentText(cleanBuffer).filter { $0.isMath }
        
        if truthSegments.isEmpty {
            print("[BufferSynthesizer] ⚠️ No formulas found in buffer via segmentText. Returning original OCR.")
            return ocrItems
        }
        
        // 2. Strict Sequential Mapping (Zip)
        // We trust Vision OCR for positioning (the "Boxes")
        // We trust Buffer for content (the "Text")
        // 2. Strict Sequential Mapping (Zip)
        // We trust Vision OCR for positioning (the "Boxes")
        // We trust Buffer for content (the "Text")
        // Crucial: We must ONLY map to boxes that OCR actually identified as Math candidates.
        
        var results = ocrItems // Start with original
        
        // Filter candidates
        let rawCandidatesIndices = ocrItems.indices.filter { !ocrItems[$0].mathFragments.isEmpty }
        
        // SORT candidates by Reading Order (Top-to-Bottom, Left-to-Right)
        // Vision coords: (0,0) is Bottom-Left. Top is High Y.
        // So we sort by Y Descending. If Y is similar, sort by X Ascending.
        let sortedCandidatesIndices = rawCandidatesIndices.sorted { idx1, idx2 in
            let item1 = ocrItems[idx1]
            let item2 = ocrItems[idx2]
            
            let y1 = item1.boundingBox.origin.y
            let y2 = item2.boundingBox.origin.y
            
            // Tolerance for "same line" (e.g. 1% of screen height)
            if abs(y1 - y2) < 0.01 {
                return item1.boundingBox.origin.x < item2.boundingBox.origin.x
            }
            return y1 > y2 // Higher Y = Earlier in reading order
        }
        
        let matchCount = min(sortedCandidatesIndices.count, truthSegments.count)
        
        if matchCount < truthSegments.count {
            print("[BufferSynthesizer] ⚠️ OCR Math Candidates (\(sortedCandidatesIndices.count)) < Buffer Formulas (\(truthSegments.count)). Some formulas will not be shown.")
        }
        
        for i in 0..<matchCount {
            // Use the SORTED index to pick the spatial "First" box
            let ocrIndex = sortedCandidatesIndices[i]
            let truthSegment = truthSegments[i]
            let originalItem = ocrItems[ocrIndex]
            
            // Overwrite the VALID Math box with simple Truth content
            // The Truth is sequential text (Buffer), so it maps to the Spatial First item.
            let updatedItem = updateItem(originalItem, with: truthSegment.text)
            results[ocrIndex] = updatedItem
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("[BufferSynthesizer] Synced \(matchCount)/\(ocrItems.count) items via Sorted Slot-Filling in \(String(format: "%.3f", duration))s")
        
        return results
    }
    
    // Legacy support for unused tail loop in simple zip (removed in this filtered version)
    // We just return the modified array.
    
    /* 
    private func updateItem... (stays same)
    */
    
    private func updateItem(_ item: RecognizedTextItem, with correctedText: String) -> RecognizedTextItem {
        // Since we trust the Buffer Text 100%, we treat the whole string as one valid LaTeX block
        // (because it came from `detector.segmentText` which isolates blocks).
        
        let cleanedText = LaTeXUtils.cleanOCRLaTeX(correctedText)
        // We use the original bounding box from OCR (item.boundingBox)
        let fragment = MathFragment(text: cleanedText, boundingBox: item.boundingBox)
        
        return RecognizedTextItem(
            id: item.id,
            text: correctedText,
            boundingBox: item.boundingBox,
            mathFragments: [fragment]
        )
    }
    
    private func stripANSI(_ text: String) -> String {
        // 1. Remove ANSI escape sequences
        let pattern = "\\x1B\\[[0-?]*[ -/]*[@-~]"
        var clean = text
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: text.utf16.count)
            clean = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        
        // 2. Normalize distinct visual separators to standard spaces
        // OCR often sees bullets (•) or dashes where terminals use spaces or special chars
        clean = clean.replacingOccurrences(of: "•", with: " ")
                     .replacingOccurrences(of: "·", with: " ")
                     .replacingOccurrences(of: "—", with: "-")
        
        return clean
    }
}
