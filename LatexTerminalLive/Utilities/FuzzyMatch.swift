import Foundation

struct FuzzyMatch {
    /// Calculates the Levenshtein distance between two strings.
    static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Count = s1.count
        let s2Count = s2.count
        
        if abs(s1Count - s2Count) > 100 { return 101 } // Too different to matter for alignment
        
        if s1Count == 0 { return s2Count }
        if s2Count == 0 { return s1Count }
        
        let s1Chars = Array(s1)
        let s2Chars = Array(s2)
        
        var previousRow = [Int](0...s2Count)
        var currentRow = [Int](repeating: 0, count: s2Count + 1)
        
        for i in 1...s1Count {
            currentRow[0] = i
            for j in 1...s2Count {
                let cost = (s1Chars[i - 1] == s2Chars[j - 1]) ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,       // Deletion
                    currentRow[j - 1] + 1,    // Insertion
                    previousRow[j - 1] + cost // Substitution
                )
            }
            previousRow = currentRow
        }
        
        return previousRow[s2Count]
    }
    
    /// Finds the closest match from a list of candidates.
    /// Returns the best match if the distance is within the maxDistance, otherwise nil.
    static func findBestMatch(for query: String, in candidates: [String], maxDistance: Int = 2) -> String? {
        var bestMatch: String? = nil
        var bestDistance = Int.max
        
        for candidate in candidates {
            // Optimization: Skip if length difference is already greater than best found or max allowed
            if abs(candidate.count - query.count) > maxDistance { continue }
            
            let distance = levenshteinDistance(query, candidate)
            
            if distance <= maxDistance && distance < bestDistance {
                bestDistance = distance
                bestMatch = candidate
                
                // Perfect match found
                if distance == 0 { return candidate }
            }
        }
        
        return bestMatch
    }
}
