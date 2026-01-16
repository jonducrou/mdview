import XCTest
@testable import MarkdownParserLib

final class MarkdownParserTests: XCTestCase {

    // MARK: - Headers

    func testH1() {
        let result = MarkdownParser.toHTML("# Hello")
        XCTAssertTrue(result.contains("<h1>Hello</h1>"))
    }

    func testH2() {
        let result = MarkdownParser.toHTML("## Hello")
        XCTAssertTrue(result.contains("<h2>Hello</h2>"))
    }

    func testH3() {
        let result = MarkdownParser.toHTML("### Hello")
        XCTAssertTrue(result.contains("<h3>Hello</h3>"))
    }

    func testH4() {
        let result = MarkdownParser.toHTML("#### Hello")
        XCTAssertTrue(result.contains("<h4>Hello</h4>"))
    }

    func testH5() {
        let result = MarkdownParser.toHTML("##### Hello")
        XCTAssertTrue(result.contains("<h5>Hello</h5>"))
    }

    func testH6() {
        let result = MarkdownParser.toHTML("###### Hello")
        XCTAssertTrue(result.contains("<h6>Hello</h6>"))
    }

    func testMultipleHeaders() {
        let md = """
        # Title
        ## Subtitle
        ### Section
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<h1>Title</h1>"))
        XCTAssertTrue(result.contains("<h2>Subtitle</h2>"))
        XCTAssertTrue(result.contains("<h3>Section</h3>"))
    }

    // MARK: - Bold and Italic

    func testBold() {
        let result = MarkdownParser.toHTML("This is **bold** text")
        XCTAssertTrue(result.contains("<strong>bold</strong>"))
    }

    func testItalic() {
        let result = MarkdownParser.toHTML("This is *italic* text")
        XCTAssertTrue(result.contains("<em>italic</em>"))
    }

    func testBoldItalic() {
        let result = MarkdownParser.toHTML("This is ***bold italic*** text")
        XCTAssertTrue(result.contains("<strong><em>bold italic</em></strong>"))
    }

    func testMultipleBoldInLine() {
        let result = MarkdownParser.toHTML("**one** and **two**")
        XCTAssertTrue(result.contains("<strong>one</strong>"))
        XCTAssertTrue(result.contains("<strong>two</strong>"))
    }

    // MARK: - Code

    func testInlineCode() {
        let result = MarkdownParser.toHTML("Use `print()` function")
        XCTAssertTrue(result.contains("<code>print()</code>"))
    }

    func testCodeBlock() {
        let md = """
        ```swift
        let x = 1
        ```
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<pre><code class=\"language-swift\">"))
        XCTAssertTrue(result.contains("let x = 1"))
        XCTAssertTrue(result.contains("</code></pre>"))
    }

    func testCodeBlockNoLanguage() {
        let md = """
        ```
        plain code
        ```
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<pre><code class=\"language-\">"))
        XCTAssertTrue(result.contains("plain code"))
    }

    // MARK: - Links and Images

    func testLink() {
        let result = MarkdownParser.toHTML("[Google](https://google.com)")
        XCTAssertTrue(result.contains("<a href=\"https://google.com\">Google</a>"))
    }

    func testImage() {
        let result = MarkdownParser.toHTML("![Alt text](image.png)")
        XCTAssertTrue(result.contains("<img src=\"image.png\" alt=\"Alt text\">"))
    }

    func testImageEmptyAlt() {
        let result = MarkdownParser.toHTML("![](image.png)")
        XCTAssertTrue(result.contains("<img src=\"image.png\" alt=\"\">"))
    }

    // MARK: - Lists

    func testUnorderedListAsterisk() {
        let md = """
        * Item 1
        * Item 2
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<li>Item 1</li>"))
        XCTAssertTrue(result.contains("<li>Item 2</li>"))
        XCTAssertTrue(result.contains("<ul>"))
    }

    func testUnorderedListDash() {
        let md = """
        - Item 1
        - Item 2
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<li>Item 1</li>"))
        XCTAssertTrue(result.contains("<li>Item 2</li>"))
    }

    func testOrderedList() {
        let md = """
        1. First
        2. Second
        3. Third
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<li>First</li>"))
        XCTAssertTrue(result.contains("<li>Second</li>"))
        XCTAssertTrue(result.contains("<li>Third</li>"))
    }

    // MARK: - Horizontal Rules

    func testHorizontalRuleDashes() {
        let result = MarkdownParser.toHTML("---")
        XCTAssertTrue(result.contains("<hr>"))
    }

    func testHorizontalRuleManyDashes() {
        // Test with more than 3 dashes
        let result = MarkdownParser.toHTML("----------")
        XCTAssertTrue(result.contains("<hr>"))
    }

    func testHorizontalRuleUnderscores() {
        let result = MarkdownParser.toHTML("___")
        XCTAssertTrue(result.contains("<hr>"))
    }

    // MARK: - Blockquotes

    func testBlockquote() {
        let result = MarkdownParser.toHTML("> This is a quote")
        XCTAssertTrue(result.contains("<blockquote>This is a quote</blockquote>"))
    }

    // MARK: - Tables

    func testSimpleTable() {
        let md = """
        | Name | Age |
        |------|-----|
        | Alice | 30 |
        | Bob | 25 |
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<table>"))
        XCTAssertTrue(result.contains("<thead>"))
        XCTAssertTrue(result.contains("<th>Name</th>"))
        XCTAssertTrue(result.contains("<th>Age</th>"))
        XCTAssertTrue(result.contains("<tbody>"))
        XCTAssertTrue(result.contains("<td>Alice</td>"))
        XCTAssertTrue(result.contains("<td>30</td>"))
        XCTAssertTrue(result.contains("<td>Bob</td>"))
        XCTAssertTrue(result.contains("<td>25</td>"))
        XCTAssertTrue(result.contains("</table>"))
    }

    func testTableWithoutLeadingPipe() {
        let md = """
        Name | Age
        -----|-----
        Alice | 30
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<table>"))
        XCTAssertTrue(result.contains("<th>Name</th>"))
        XCTAssertTrue(result.contains("<td>Alice</td>"))
    }

    func testMultipleTables() {
        let md = """
        | A | B |
        |---|---|
        | 1 | 2 |

        Some text

        | C | D |
        |---|---|
        | 3 | 4 |
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<th>A</th>"))
        XCTAssertTrue(result.contains("<th>B</th>"))
        XCTAssertTrue(result.contains("<td>1</td>"))
        XCTAssertTrue(result.contains("<th>C</th>"))
        XCTAssertTrue(result.contains("<th>D</th>"))
        XCTAssertTrue(result.contains("<td>3</td>"))
    }

    func testTableWithAlignmentMarkers() {
        let md = """
        | Left | Center | Right |
        |:-----|:------:|------:|
        | L | C | R |
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<table>"))
        XCTAssertTrue(result.contains("<th>Left</th>"))
        XCTAssertTrue(result.contains("<td>L</td>"))
    }

    // MARK: - HTML Escaping

    func testHTMLEscapingAmpersand() {
        // Ampersands get escaped
        let result = MarkdownParser.toHTML("Tom & Jerry")
        XCTAssertTrue(result.contains("Tom &amp; Jerry"))
    }

    func testHTMLEscapingPreservesGeneratedTags() {
        let md = """
        | Col |
        |-----|
        | Val |
        """
        let result = MarkdownParser.toHTML(md)
        // Should have real <table> tags, not escaped
        XCTAssertTrue(result.contains("<table>"))
        XCTAssertFalse(result.contains("&lt;table&gt;"))
    }

    // MARK: - Paragraphs

    func testParagraphWrapping() {
        let result = MarkdownParser.toHTML("Hello world")
        XCTAssertTrue(result.contains("<p>Hello world</p>"))
    }

    func testMultipleParagraphs() {
        let md = """
        First paragraph.

        Second paragraph.
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<p>First paragraph.</p>"))
        XCTAssertTrue(result.contains("<p>Second paragraph.</p>"))
    }

    func testLineBreaksInParagraph() {
        let md = "Line one\nLine two"
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("Line one<br>Line two"))
    }

    // MARK: - Edge Cases

    func testEmptyInput() {
        let result = MarkdownParser.toHTML("")
        XCTAssertEqual(result, "")
    }

    func testWhitespaceOnly() {
        let result = MarkdownParser.toHTML("   \n\n   ")
        XCTAssertFalse(result.contains("<p>   </p>"))
    }

    func testMixedContent() {
        let md = """
        # Welcome

        This is **bold** and *italic* with `code`.

        | Feature | Status |
        |---------|--------|
        | Tables | Done |

        - Item 1
        - Item 2

        > A quote

        ---

        [Link](https://example.com)
        """
        let result = MarkdownParser.toHTML(md)
        XCTAssertTrue(result.contains("<h1>Welcome</h1>"))
        XCTAssertTrue(result.contains("<strong>bold</strong>"))
        XCTAssertTrue(result.contains("<em>italic</em>"))
        XCTAssertTrue(result.contains("<code>code</code>"))
        XCTAssertTrue(result.contains("<table>"))
        XCTAssertTrue(result.contains("<li>Item 1</li>"))
        XCTAssertTrue(result.contains("<blockquote>"))
        XCTAssertTrue(result.contains("<hr>"))
        XCTAssertTrue(result.contains("<a href=\"https://example.com\">Link</a>"))
    }

    // MARK: - processTables unit tests

    func testProcessTablesDoesNotAffectNonTables() {
        let md = "Just some text with | pipe"
        let result = MarkdownParser.processTables(md)
        XCTAssertEqual(result, md)
    }

    func testConvertTableToHTMLMinimumRows() {
        let lines = ["| A |", "|---|"]
        let result = MarkdownParser.convertTableToHTML(lines)
        XCTAssertTrue(result.contains("<table>"))
        XCTAssertTrue(result.contains("<th>A</th>"))
        XCTAssertTrue(result.contains("<tbody>"))
    }

    func testConvertTableToHTMLInsufficientRows() {
        let lines = ["| A |"]
        let result = MarkdownParser.convertTableToHTML(lines)
        XCTAssertEqual(result, "| A |")
    }

    // MARK: - escapeHTMLOutsideTags unit tests

    func testEscapeHTMLAmpersand() {
        // Ampersands outside tags get escaped
        let result = MarkdownParser.escapeHTMLOutsideTags("foo & bar")
        XCTAssertEqual(result, "foo &amp; bar")
    }

    func testEscapeHTMLPreservesTags() {
        let result = MarkdownParser.escapeHTMLOutsideTags("<table>content & more</table>")
        XCTAssertTrue(result.contains("<table>"))
        XCTAssertTrue(result.contains("</table>"))
        XCTAssertTrue(result.contains("&amp;"))
    }
}
