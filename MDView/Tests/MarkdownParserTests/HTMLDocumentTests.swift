import XCTest
@testable import MarkdownParserLib

final class HTMLDocumentTests: XCTestCase {

    // MARK: - makePage structure

    func testMakePageHasDoctypeCharsetStyleAndHighlightAll() {
        let page = HTMLDocument.makePage(markdown: "Hello")
        XCTAssertTrue(page.contains("<!DOCTYPE html>"))
        XCTAssertTrue(page.contains("<meta charset=\"utf-8\">"))
        XCTAssertTrue(page.contains("<style>"))
        XCTAssertTrue(page.contains("hljs.highlightAll()"))
    }

    func testMakePageWrapsDarkCSSInMediaQuery() {
        let page = HTMLDocument.makePage(markdown: "Hello")
        XCTAssertTrue(page.contains("@media (prefers-color-scheme: dark) {"))
    }

    func testMakePageHasBothHighlightJSThemeLinksWithMediaAttributes() {
        let page = HTMLDocument.makePage(markdown: "Hello")
        XCTAssertTrue(page.contains("github.min.css\" media=\"(prefers-color-scheme: light)\""))
        XCTAssertTrue(page.contains("github-dark.min.css\" media=\"(prefers-color-scheme: dark)\""))
    }

    func testMakePageHasHighlightJSScriptTag() {
        let page = HTMLDocument.makePage(markdown: "Hello")
        XCTAssertTrue(page.contains("highlight.min.js"))
        XCTAssertTrue(page.contains("<script src=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js\"></script>"))
    }

    func testMakePageEmbedsConvertedBody() {
        let page = HTMLDocument.makePage(markdown: "# Hello")
        XCTAssertTrue(page.contains("<h1>Hello</h1>"))
        XCTAssertTrue(page.contains(MarkdownParser.toHTML("# Hello")))
    }

    // MARK: - makePrintPage structure

    func testMakePrintPageHasDoctypeCharsetAndHighlightAll() {
        let page = HTMLDocument.makePrintPage(markdown: "Hello")
        XCTAssertTrue(page.contains("<!DOCTYPE html>"))
        XCTAssertTrue(page.contains("<meta charset=\"utf-8\">"))
        XCTAssertTrue(page.contains("hljs.highlightAll()"))
    }

    func testMakePrintPageHasLightThemeLinkWithoutMediaAttribute() {
        let page = HTMLDocument.makePrintPage(markdown: "Hello")
        XCTAssertTrue(page.contains("<link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css\">"))
    }

    func testMakePrintPageHasNoDarkColorScheme() {
        let page = HTMLDocument.makePrintPage(markdown: "Hello")
        XCTAssertFalse(page.contains("prefers-color-scheme: dark"))
    }

    func testMakePrintPageHasNoDarkThemeStylesheet() {
        let page = HTMLDocument.makePrintPage(markdown: "Hello")
        XCTAssertFalse(page.contains("github-dark.min.css"))
    }

    func testMakePrintPageEmbedsSameBodyAsMakePage() {
        let md = """
        # Title

        Some **bold** text.

        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let body = MarkdownParser.toHTML(md)
        let screenPage = HTMLDocument.makePage(markdown: md)
        let printPage = HTMLDocument.makePrintPage(markdown: md)
        XCTAssertTrue(screenPage.contains("<body>\(body)</body>"))
        XCTAssertTrue(printPage.contains("<body>\(body)</body>"))
    }

    // MARK: - CSS content

    func testLightCSSContent() {
        XCTAssertTrue(HTMLDocument.lightCSS.contains("font-family: -apple-system"))
        XCTAssertTrue(HTMLDocument.lightCSS.contains("background: #ffffff"))
        XCTAssertFalse(HTMLDocument.lightCSS.contains("@media"))
    }

    func testDarkCSSContent() {
        XCTAssertTrue(HTMLDocument.darkCSS.contains("#0d1117"))
        XCTAssertTrue(HTMLDocument.darkCSS.contains("#30363d"))
        XCTAssertFalse(HTMLDocument.darkCSS.contains("@media"))
    }

    func testScreenCSSComposition() {
        XCTAssertEqual(
            HTMLDocument.screenCSS,
            HTMLDocument.lightCSS + "\n@media (prefers-color-scheme: dark) {\n" + HTMLDocument.darkCSS + "\n}"
        )
    }

    func testMakePageContainsScreenCSS() {
        let page = HTMLDocument.makePage(markdown: "Hello")
        XCTAssertTrue(page.contains(HTMLDocument.screenCSS))
    }

    func testMakePrintPageContainsLightCSS() {
        let page = HTMLDocument.makePrintPage(markdown: "Hello")
        XCTAssertTrue(page.contains(HTMLDocument.lightCSS))
    }

    // MARK: - Robustness

    func testScriptTagAndAmpersandDoNotBreakAssembly() {
        let md = "<script>alert(1)</script> & more"
        let page = HTMLDocument.makePage(markdown: md)
        XCTAssertTrue(page.hasSuffix("</html>"))
        XCTAssertTrue(page.contains("<body>"))
        XCTAssertTrue(page.contains("</body>"))
        XCTAssertTrue(page.contains("<!DOCTYPE html>"))
        // Body payload matches parser output
        XCTAssertTrue(page.contains(MarkdownParser.toHTML(md)))
    }

    func testEmptyMarkdownProducesValidPageWithEmptyBody() {
        let page = HTMLDocument.makePage(markdown: "")
        XCTAssertTrue(page.contains("<!DOCTYPE html>"))
        XCTAssertTrue(page.contains("<body></body>"))
        XCTAssertTrue(page.hasSuffix("</html>"))

        let printPage = HTMLDocument.makePrintPage(markdown: "")
        XCTAssertTrue(printPage.contains("<body></body>"))
    }

    func testTablesCodeBlocksAndImagesPassThroughUnchanged() {
        let md = """
        # Doc

        | Name | Value |
        |------|-------|
        | a | 1 |

        ```swift
        let x = 1
        ```

        ![Alt](image.png)
        """
        let body = MarkdownParser.toHTML(md)
        XCTAssertTrue(body.contains("<table>"))
        XCTAssertTrue(body.contains("<pre><code"))
        XCTAssertTrue(body.contains("<img"))

        let page = HTMLDocument.makePage(markdown: md)
        XCTAssertTrue(page.contains(body))
        let printPage = HTMLDocument.makePrintPage(markdown: md)
        XCTAssertTrue(printPage.contains(body))
    }
}
