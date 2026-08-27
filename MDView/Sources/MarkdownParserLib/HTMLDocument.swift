import Foundation

/// Assembles full HTML pages (CSS + highlight.js boilerplate) around
/// MarkdownParser output, for on-screen viewing and for printing.
public enum HTMLDocument {

    /// Base stylesheet — light colors, no media queries.
    public static let lightCSS = """
:root {
    color-scheme: light dark;
}
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    font-size: 15px;
    line-height: 1.6;
    max-width: 900px;
    margin: 0 auto;
    padding: 20px 40px;
    color: #24292f;
    background: #ffffff;
}
h1, h2, h3, h4, h5, h6 { margin-top: 24px; margin-bottom: 16px; font-weight: 600; }
h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid #d0d7de; }
h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid #d0d7de; }
h3 { font-size: 1.25em; }
p { margin: 0 0 16px 0; }
a { color: #0969da; text-decoration: none; }
a:hover { text-decoration: underline; }
code {
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace;
    font-size: 85%;
    background: #f6f8fa;
    padding: 0.2em 0.4em;
    border-radius: 6px;
}
pre {
    background: #f6f8fa;
    padding: 16px;
    border-radius: 6px;
    overflow-x: auto;
    border: 1px solid #d0d7de;
}
pre code { background: none; padding: 0; font-size: 85%; }
blockquote {
    margin: 0 0 16px 0;
    padding: 0 1em;
    border-left: 4px solid #d0d7de;
    color: #57606a;
}
ul, ol { padding-left: 2em; margin: 0 0 16px 0; }
li { margin: 4px 0; }
hr { height: 2px; background: #d0d7de; border: 0; margin: 24px 0; }
img { max-width: 100%; height: auto; }
table {
    border-collapse: collapse;
    width: 100%;
    margin: 0 0 16px 0;
    overflow-x: auto;
    display: block;
}
th, td {
    border: 1px solid #d0d7de;
    padding: 8px 12px;
    text-align: left;
}
th {
    background: #f6f8fa;
    font-weight: 600;
}
tr:nth-child(even) { background: #f6f8fa; }
"""

    /// Dark-mode overrides (applied inside a `prefers-color-scheme: dark` media query on screen only).
    public static let darkCSS = """
    body { background: #0d1117; color: #c9d1d9; }
    a { color: #58a6ff; }
    code { background: #161b22; }
    pre { background: #161b22; border-color: #30363d; }
    blockquote { border-color: #30363d; color: #8b949e; }
    hr { background: #30363d; }
    h1, h2 { border-color: #30363d; }
    th, td { border-color: #30363d; }
    th { background: #161b22; }
    tr:nth-child(even) { background: #161b22; }
"""

    /// Full screen CSS: light rules plus dark overrides in one media query.
    public static var screenCSS: String {
        lightCSS + "\n@media (prefers-color-scheme: dark) {\n" + darkCSS + "\n}"
    }

    private static let highlightJSLight = #"<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">"#
    private static let highlightJSLightThemed = #"<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">"#
    private static let highlightJSDarkThemed = #"<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">"#
    private static let highlightJSScript = #"<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>"#

    /// Page for on-screen viewing: light + dark CSS, both highlight.js themes.
    public static func makePage(markdown: String) -> String {
        let body = MarkdownParser.toHTML(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>\(screenCSS)</style>
        \(highlightJSLightThemed)
        \(highlightJSDarkThemed)
        \(highlightJSScript)
        </head>
        <body>\(body)</body>
        <script>hljs.highlightAll();</script>
        </html>
        """
    }

    /// Page for printing: light CSS only, light highlight.js theme unconditionally.
    public static func makePrintPage(markdown: String) -> String {
        let body = MarkdownParser.toHTML(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>\(lightCSS)</style>
        \(highlightJSLight)
        \(highlightJSScript)
        </head>
        <body>\(body)</body>
        <script>hljs.highlightAll();</script>
        </html>
        """
    }
}
