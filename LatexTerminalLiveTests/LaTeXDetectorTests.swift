import XCTest
@testable import LatexTerminalLive

final class LaTeXDetectorTests: XCTestCase {

    let detector = LaTeXDetector()

    func testContainsLaTeX() {
        XCTAssertTrue(detector.containsLaTeX("This has $x$ math"))
        XCTAssertTrue(detector.containsLaTeX("This has $$x$$ display math"))
        XCTAssertTrue(detector.containsLaTeX("This has \\[x\\] bracket math"))
        XCTAssertTrue(detector.containsLaTeX("This has \\(x\\) paren math"))
        XCTAssertFalse(detector.containsLaTeX("This has no math"))
    }

    func testSegmentTextSingleDollar() {
        let input = "The value is $x = 5$ today"
        let segments = detector.segmentText(input)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].text, "The value is ")
        XCTAssertFalse(segments[0].isMath)

        XCTAssertEqual(segments[1].text, "$x = 5$")
        XCTAssertTrue(segments[1].isMath)

        XCTAssertEqual(segments[2].text, " today")
        XCTAssertFalse(segments[2].isMath)
    }

    func testSegmentTextDoubleDollar() {
        let input = "Display: $$E = mc^2$$ is famous"
        let segments = detector.segmentText(input)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].text, "Display: ")
        XCTAssertFalse(segments[0].isMath)

        XCTAssertEqual(segments[1].text, "$$E = mc^2$$")
        XCTAssertTrue(segments[1].isMath)

        XCTAssertEqual(segments[2].text, " is famous")
        XCTAssertFalse(segments[2].isMath)
    }

    func testSegmentTextBrackets() {
        let input = "Formula \\[x + y\\] here"
        let segments = detector.segmentText(input)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[1].text, "\\[x + y\\]")
        XCTAssertTrue(segments[1].isMath)
    }

    func testSegmentTextParentheses() {
        let input = "Inline \\(a + b\\) formula"
        let segments = detector.segmentText(input)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[1].text, "\\(a + b\\)")
        XCTAssertTrue(segments[1].isMath)
    }

    func testSegmentTextMultipleMath() {
        let input = "First $x$ and second $y$ formula"
        let segments = detector.segmentText(input)

        XCTAssertEqual(segments.count, 5)
        XCTAssertTrue(segments[1].isMath)
        XCTAssertTrue(segments[3].isMath)
        XCTAssertEqual(segments[1].text, "$x$")
        XCTAssertEqual(segments[3].text, "$y$")
    }

    func testSegmentTextUnmatchedDelimiter() {
        // If no closing delimiter, treat as literal text
        let input = "Unmatched $x and more"
        let segments = detector.segmentText(input)

        // Should not find math since no closing $
        XCTAssertTrue(segments.allSatisfy { !$0.isMath })
    }

    func testSegmentTextEscapedDollar() {
        // Escaped dollar should not be treated as delimiter
        let input = "Price is \\$5 today"
        let segments = detector.segmentText(input)

        // Should not find math
        XCTAssertTrue(segments.allSatisfy { !$0.isMath })
    }

    func testSegmentTextNestedBraces() {
        let input = "Formula $\\frac{1}{2}$ here"
        let segments = detector.segmentText(input)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[1].text, "$\\frac{1}{2}$")
        XCTAssertTrue(segments[1].isMath)
    }
}
