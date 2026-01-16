import Foundation

// MARK: - Markdown Parser (lightweight, no dependencies)
public struct MarkdownParser {
    public init() {}

    public static func toHTML(_ markdown: String) -> String {
        // First, extract and process tables before escaping
        var processedMarkdown = markdown
        processedMarkdown = processTables(processedMarkdown)

        var html = processedMarkdown

        // Escape HTML entities (but not in already-processed table HTML)
        html = escapeHTMLOutsideTags(html)

        // Code blocks (fenced) - must be done before other processing
        html = html.replacingOccurrences(
            of: "```(\\w*)\\n([\\s\\S]*?)```",
            with: "<pre><code class=\"language-$1\">$2</code></pre>",
            options: .regularExpression
        )

        // Inline code
        html = html.replacingOccurrences(
            of: "`([^`]+)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Headers
        html = html.replacingOccurrences(of: "(?m)^###### (.+)$", with: "<h6>$1</h6>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^##### (.+)$", with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#### (.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)

        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*", with: "<strong><em>$1</em></strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)

        // Links and images
        html = html.replacingOccurrences(of: "!\\[([^\\]]*?)\\]\\(([^)]+)\\)", with: "<img src=\"$2\" alt=\"$1\">", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\[([^\\]]+?)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)

        // Horizontal rules
        html = html.replacingOccurrences(of: "(?m)^(-{3,}|\\*{3,}|_{3,})$", with: "<hr>", options: .regularExpression)

        // Blockquotes
        html = html.replacingOccurrences(of: "(?m)^&gt; (.+)$", with: "<blockquote>$1</blockquote>", options: .regularExpression)

        // Unordered lists
        html = html.replacingOccurrences(of: "(?m)^[*-] (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Ordered lists
        html = html.replacingOccurrences(of: "(?m)^\\d+\\. (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Wrap consecutive <li> in <ul>
        html = html.replacingOccurrences(of: "(<li>.*?</li>\\n?)+", with: "<ul>$0</ul>", options: .regularExpression)

        // Paragraphs - wrap lines that aren't already wrapped
        let lines = html.components(separatedBy: "\n\n")
        html = lines.map { block in
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "" }
            if trimmed.hasPrefix("<h") || trimmed.hasPrefix("<ul") || trimmed.hasPrefix("<ol") ||
               trimmed.hasPrefix("<pre") || trimmed.hasPrefix("<blockquote") || trimmed.hasPrefix("<hr") ||
               trimmed.hasPrefix("<table") {
                return trimmed
            }
            return "<p>\(trimmed.replacingOccurrences(of: "\n", with: "<br>"))</p>"
        }.joined(separator: "\n")

        return html
    }

    public static func processTables(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            // Check if this line looks like a table row (contains |)
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.contains("|") && i + 1 < lines.count {
                let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)

                // Check if next line is a separator (contains | and - and mostly dashes/pipes/colons)
                let isSeparator = nextLine.contains("|") && nextLine.contains("-") &&
                    nextLine.replacingOccurrences(of: "|", with: "")
                           .replacingOccurrences(of: "-", with: "")
                           .replacingOccurrences(of: ":", with: "")
                           .replacingOccurrences(of: " ", with: "").isEmpty

                if isSeparator {
                    // Found a table, collect all rows
                    var tableLines: [String] = [line, nextLine]
                    var j = i + 2
                    while j < lines.count {
                        let rowLine = lines[j].trimmingCharacters(in: .whitespaces)
                        if rowLine.contains("|") && !rowLine.isEmpty {
                            tableLines.append(rowLine)
                            j += 1
                        } else {
                            break
                        }
                    }

                    // Convert table to HTML and replace lines
                    let tableHTML = convertTableToHTML(tableLines)
                    lines.removeSubrange(i..<j)
                    lines.insert(tableHTML, at: i)
                    // Don't increment i, process next line after inserted HTML
                    i += 1
                    continue
                }
            }
            i += 1
        }

        return lines.joined(separator: "\n")
    }

    public static func convertTableToHTML(_ lines: [String]) -> String {
        guard lines.count >= 2 else { return lines.joined(separator: "\n") }

        func parseCells(_ line: String) -> [String] {
            var cells = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
            // Remove empty first/last if line starts/ends with |
            if cells.first?.isEmpty == true { cells.removeFirst() }
            if cells.last?.isEmpty == true { cells.removeLast() }
            return cells
        }

        let headerCells = parseCells(lines[0])
        // Skip separator line (lines[1])
        let bodyRows = lines.dropFirst(2).map { parseCells($0) }

        var html = "<table>\n<thead>\n<tr>"
        for cell in headerCells {
            html += "<th>\(cell)</th>"
        }
        html += "</tr>\n</thead>\n<tbody>\n"

        for row in bodyRows {
            html += "<tr>"
            for cell in row {
                html += "<td>\(cell)</td>"
            }
            html += "</tr>\n"
        }

        html += "</tbody>\n</table>"
        return html
    }

    public static func escapeHTMLOutsideTags(_ text: String) -> String {
        // Simple approach: escape &, <, > but preserve existing HTML tags from tables
        var result = ""
        var inTag = false

        for char in text {
            if char == "<" && !inTag {
                // Check if this looks like our generated HTML tag
                inTag = true
                result.append(char)
            } else if char == ">" && inTag {
                inTag = false
                result.append(char)
            } else if inTag {
                result.append(char)
            } else {
                switch char {
                case "&": result.append("&amp;")
                case "<": result.append("&lt;")
                case ">": result.append("&gt;")
                default: result.append(char)
                }
            }
        }
        return result
    }
}
