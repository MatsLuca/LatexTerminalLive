import XCTest
@testable import LatexTerminalLive

final class LaTeXUtilsTests: XCTestCase {

    func testBasicCleanup() {
        // Test backslash space removal
        let input = "\\ sum"
        let expected = "\\sum"
        XCTAssertEqual(LaTeXUtils.cleanOCRLaTeX(input), expected)
    }

    func testGreekLetterUnification() {
        // Test that mixed Lambda/lambda gets unified to majority
        let input = "$\\lambda + \\lambda + \\Lambda$"
        let output = LaTeXUtils.cleanOCRLaTeX(input)
        // Should unify to \lambda (2 vs 1)
        XCTAssertTrue(output.contains("\\lambda"))
        XCTAssertFalse(output.contains("\\Lambda"))
    }

    func testFractionRepair() {
        // Test missing opening brace
        let input = "\\frac 33}{5}"
        let output = LaTeXUtils.cleanOCRLaTeX(input)
        XCTAssertTrue(output.contains("\\frac{33}"))
    }

    func testGermanDecimalSeparator() {
        // Test decimal comma repair
        let input = "16f,}6"
        let expected = "16{,}6"
        XCTAssertEqual(LaTeXUtils.cleanOCRLaTeX(input), expected)
    }

    func testEllipsisRepair() {
        // Test \dot to \dots conversion
        let input = "$x \\dot = 5$"
        let output = LaTeXUtils.cleanOCRLaTeX(input)
        XCTAssertTrue(output.contains("\\dots"))
        // Verify \dot was replaced (not just checking if "dot" substring exists)
        XCTAssertFalse(output.contains("\\dot "))
        XCTAssertFalse(output.contains("\\dot="))
    }

    func testBraceBalancing() {
        // Test that extra closing braces are removed
        let input = "\\frac{1}{2}}}"
        let output = LaTeXUtils.cleanOCRLaTeX(input)
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        XCTAssertEqual(openCount, closeCount)
    }

    func testEnvironmentRepair() {
        // Test environment name repair
        let input = "\\begin{pmatrix)"
        let output = LaTeXUtils.cleanOCRLaTeX(input)
        XCTAssertTrue(output.contains("\\begin{pmatrix}"))
    }

    func testZArtifactCleaning() {
        // Test Z-prefix removal
        let input = "\\Zambda"
        let expected = "\\lambda"
        XCTAssertEqual(LaTeXUtils.cleanOCRLaTeX(input), expected)
    }
}
