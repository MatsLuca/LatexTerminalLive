import Vision
import CoreGraphics
import SwiftUI

struct MathFragment: Identifiable, Equatable {
    let id: UUID
    let text: String
    let boundingBox: CGRect // Normalized sub-rect
    
    init(id: UUID = UUID(), text: String, boundingBox: CGRect) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
    }
    
    static func == (lhs: MathFragment, rhs: MathFragment) -> Bool {
        let coordTolerance = Constants.Geometry.coordinateTolerance
        return lhs.text == rhs.text &&
               abs(lhs.boundingBox.origin.x - rhs.boundingBox.origin.x) < coordTolerance &&
               abs(lhs.boundingBox.origin.y - rhs.boundingBox.origin.y) < coordTolerance &&
               abs(lhs.boundingBox.size.width - rhs.boundingBox.size.width) < coordTolerance &&
               abs(lhs.boundingBox.size.height - rhs.boundingBox.size.height) < coordTolerance
    }
}

struct RecognizedTextItem: Identifiable, Equatable {
    let id: UUID
    let text: String
    let boundingBox: CGRect // Full item box
    let mathFragments: [MathFragment]
    
    init(id: UUID = UUID(), text: String, boundingBox: CGRect, mathFragments: [MathFragment]) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.mathFragments = mathFragments
    }
    
    static func == (lhs: RecognizedTextItem, rhs: RecognizedTextItem) -> Bool {
        let coordTolerance = Constants.Geometry.coordinateTolerance
        return lhs.text == rhs.text &&
               lhs.mathFragments == rhs.mathFragments &&
               abs(lhs.boundingBox.origin.x - rhs.boundingBox.origin.x) < coordTolerance &&
               abs(lhs.boundingBox.origin.y - rhs.boundingBox.origin.y) < coordTolerance
    }
}

class VisionOCR {
    private let detector = LaTeXDetector()
    private static var lastLoggedText: String = ""
    private static var lastLogTime: Date = .distantPast
    
    func recognizeText(in image: CGImage) async throws -> (items: [RecognizedTextItem], theme: AppTheme) {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    let theme = ColorUtils.detectTheme(from: image, textItems: [])
                    continuation.resume(returning: ([], theme))
                    return
                }
                
                let results = observations.compactMap { observation -> RecognizedTextItem? in
                    guard let topCandidate = observation.topCandidates(1).first else { return nil }
                    let fullText = topCandidate.string
                    
                    // Identify math parts in the string
                    let segments = self.detector.segmentText(fullText)
                    var mathFragments: [MathFragment] = []
                    
                    var currentIndex = 0
                    for segment in segments {
                        if segment.isMath {
                            let cleanedText = LaTeXUtils.cleanOCRLaTeX(segment.text)
                            let nsRange = NSRange(location: currentIndex, length: segment.text.count)
                            if let swiftRange = Range(nsRange, in: fullText),
                               let box = try? topCandidate.boundingBox(for: swiftRange) {
                                mathFragments.append(MathFragment(text: cleanedText, boundingBox: box.boundingBox))
                            }
                        }
                        currentIndex += segment.text.count
                    }
                    
                    return RecognizedTextItem(
                        text: fullText,
                        boundingBox: observation.boundingBox,
                        mathFragments: mathFragments
                    )
                }
                
                let mathSummaries = results.compactMap { item -> String? in
                    guard !item.mathFragments.isEmpty else { return nil }
                    return item.text
                }
                
                if !mathSummaries.isEmpty {
                    let fullScene = mathSummaries.joined(separator: " | ")
                    if fullScene != VisionOCR.lastLoggedText || Date().timeIntervalSince(VisionOCR.lastLogTime) > Constants.Timing.logDebounceInterval {
                        DebugLog.ocr("Math Scene: \(fullScene)")
                        VisionOCR.lastLoggedText = fullScene
                        VisionOCR.lastLogTime = Date()
                    }
                }
                
                let theme = ColorUtils.detectTheme(from: image, textItems: results)
                continuation.resume(returning: (results, theme))
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
