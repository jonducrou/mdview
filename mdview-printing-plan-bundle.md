===== SPEC: docs/superpowers/specs/2026-08-26-printing-design.md =====
# MDView Printing — Design Spec

Date: 2026-08-26
Status: Approved by user

## Goal

Add printing to MDView: **File → Print…** (`Cmd+P`) generates a light-styled PDF of the rendered document and opens it in the default PDF app (Preview), where the user prints. No in-app print panel.

## User-facing behavior

- New File menu item **Print…**, key equivalent `Cmd+P`, targeting the front `DocumentWindow`.
- The PDF is named after the source file (`<name>.pdf`), written to `NSTemporaryDirectory()`, and opened via `NSWorkspace.shared.open(_:)`.
- If no file is loaded in the front window (welcome screen) → alert: "Nothing to print."
- Printing re-parses from `currentFile`, so it always reflects the latest on-disk content.
- Output is **always light-styled**, regardless of system dark mode.

## Architecture

### Extract HTML assembly into `MarkdownParserLib` (testable)

The full-page HTML assembly (CSS embedding + highlight.js boilerplate) currently lives inline in `DocumentWindow.loadFile`. Move it into a new `Sources/MarkdownParserLib/HTMLDocument.swift` so it is unit-testable (the `MDView` executable target is not importable by tests).

Public interface:

```swift
public enum HTMLDocument {
    /// Base (light) CSS — all current rules except the two dark @media blocks.
    public static var lightCSS: String { get }
    /// Dark-mode override rules (contents of the @media blocks, unwrapped).
    public static var darkCSS: String { get }
    /// Screen page: lightCSS + @media(prefers-color-scheme: dark){darkCSS},
    /// light & dark highlight.js themes, hljs.highlightAll().
    public static func makePage(markdown: String) -> String
    /// Print page: lightCSS only, light highlight.js theme only, hljs.highlightAll().
    public static func makePrintPage(markdown: String) -> String
}
```

Screen HTML output must be byte-identical in behavior to today's page (same CSS rules, same CDN links/scripts).

### App changes (`Sources/MDView/main.swift`)

- `DocumentWindow.loadFile` uses `HTMLDocument.makePage(markdown:)` instead of inline assembly.
- `showWelcome` / `showError` keep their simple pages, using `HTMLDocument.lightCSS`.
- New `DocumentWindow.printDocument()`:
  1. Guard `currentFile` (else caller alerts).
  2. Read file, build `HTMLDocument.makePrintPage(markdown:)`.
  3. Write print HTML to a temp file next to the source file (same naming/access pattern as `loadFile`, so local images resolve via `loadFileURL(_, allowingReadAccessTo:)`).
  4. Render in a hidden offscreen `WKWebView`; on `didFinish` navigation, call `createPDF` (macOS 11+; deployment target is 12).
  5. Write PDF data to `NSTemporaryDirectory()/MDView-<name>.pdf`, open with `NSWorkspace.shared.open`.
  6. Delete the temp print HTML after PDF generation. Offscreen webView released after completion.
- New `AppDelegate.printDocument()` `@objc` action: finds front `DocumentWindow`; calls `printDocument()` or shows the "nothing to print" alert.
- Menu: File menu gains **Print…** (`p`) after Reload.

### Error handling

- File unreadable → alert "Could not read file".
- `createPDF` failure → alert "Could not generate PDF".

## Testing

New test suite `Tests/MarkdownParserTests/HTMLDocumentTests.swift` covering:

- `makePage` output contains: DOCTYPE, charset meta, `prefers-color-scheme: dark` media query, both highlight.js themes (light + dark), highlight.js script, `hljs.highlightAll()`, and the converted markdown body.
- `makePrintPage` output contains: DOCTYPE, charset meta, light CSS rules, light highlight.js theme, `hljs.highlightAll()`, converted body — and does **not** contain `prefers-color-scheme: dark` or the dark highlight.js theme.
- `lightCSS` contains base rules (e.g. `font-family: -apple-system`) and no `@media`; `darkCSS` contains dark rules (e.g. `#0d1117`) and no `@media`.
- `lightCSS + @media wrapper(darkCSS)` reconstructs the full screen CSS (consistency check against `makePage`).
- Body content passes through `MarkdownParser.toHTML` unchanged (headers, code blocks, tables).
- Special characters in markdown (e.g. `<script>`, `&`) don't break page assembly.

Manual verification: build + bundle, open a test `.md` (with images, tables, code) in both light and dark mode, `Cmd+P`, confirm the Preview-opened PDF is light-styled, complete, and correctly paginated.

## Out of scope (YAGNI)

- In-app `NSPrintOperation` print panel.
- Print settings (margins, header/footer) customization.
- Direct-to-printer printing without Preview.

===== PLAN: docs/superpowers/plans/2026-08-26-printing.md =====
# MDView Printing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add File → Print… (`Cmd+P`) to MDView, which renders the document light-styled, exports a PDF via an offscreen `WKWebView.createPDF`, and opens it in Preview for printing.

**Architecture:** HTML page assembly is extracted from `main.swift` into a new testable `HTMLDocument` enum in `MarkdownParserLib` (light CSS / dark overrides split). The app gains a `PrintRenderer` helper (offscreen WKWebView → PDF → `NSWorkspace.open`) driven by a new `DocumentWindow.printDocument()` and File menu item.

**Tech Stack:** Swift 5.9, AppKit, WebKit (`createPDF`, macOS 11+; deployment target 12), XCTest.

**Spec:** `docs/superpowers/specs/2026-08-26-printing-design.md`

**Git policy:** Do NOT run `git commit` or any git mutation — the user has not authorized commits.

---

### Task 1: Extract `HTMLDocument` into MarkdownParserLib

**Files:**
- Create: `MDView/Sources/MarkdownParserLib/HTMLDocument.swift`

The CSS content below is moved verbatim from the current `let css = """..."""` in `MDView/Sources/MDView/main.swift` (lines 63–140), split into light rules and dark overrides.

- [ ] **Step 1: Create the file with this exact content**

```swift
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
```

- [ ] **Step 2: Build the library**

Run: `cd MDView && swift build 2>&1 | tail -5`
Expected: `Build complete!` (the app target will fail to build until Task 3 removes the old `css` global — building just the lib is enough: `swift build --target MarkdownParserLib`)

---

### Task 2: Unit test suite for HTMLDocument (assigned to test-writing subagent)

**Files:**
- Create: `MDView/Tests/MarkdownParserTests/HTMLDocumentTests.swift`

Write a complete XCTest suite (`import XCTest` + `@testable import MarkdownParserLib` — match the existing test files' import style; check `Tests/MarkdownParserTests/` for the convention). Cover at minimum:

- [ ] **Step 1: Structure tests for `makePage`**
  - contains `<!DOCTYPE html>`, `<meta charset="utf-8">`, `<style>`, `hljs.highlightAll()`
  - contains the `@media (prefers-color-scheme: dark)` wrapper
  - contains both highlight.js theme links, each with the correct `media="(prefers-color-scheme: light)"` / `media="(prefers-color-scheme: dark)"` attribute
  - contains the highlight.js script tag (`highlight.min.js`)
  - embeds the converted body: `makePage(markdown: "# Hello")` contains `<h1>Hello</h1>` (verify actual parser output against `MarkdownParser.toHTML("# Hello")` first and assert equality with the substring `MarkdownParser.toHTML` returns)
- [ ] **Step 2: Structure tests for `makePrintPage`**
  - contains `<!DOCTYPE html>`, charset meta, `hljs.highlightAll()`, light highlight.js theme link **without** a media attribute
  - does NOT contain `prefers-color-scheme: dark`
  - does NOT contain `github-dark.min.css`
  - embeds the converted body identically to `makePage` (same markdown in → same `<body>` payload)
- [ ] **Step 3: CSS content tests**
  - `lightCSS` contains `font-family: -apple-system` and `background: #ffffff`; contains no `@media`
  - `darkCSS` contains `#0d1117` and `#30363d`; contains no `@media`
  - `screenCSS` == `lightCSS + "\n@media (prefers-color-scheme: dark) {\n" + darkCSS + "\n}"` (exact equality)
  - `makePage` contains `screenCSS`; `makePrintPage` contains `lightCSS`
- [ ] **Step 4: Robustness tests**
  - markdown containing `<script>alert(1)</script>` and `&` does not break assembly (output still well-formed: ends with `</html>`, body present)
  - empty markdown produces a valid page with an empty body
  - markdown with tables/code blocks/images passes through unchanged (compare against `MarkdownParser.toHTML` output)
- [ ] **Step 5: Run the tests**

Run: `cd MDView && swift test --filter HTMLDocumentTests`
Expected: all pass

---

### Task 3: App wiring — use HTMLDocument, add PrintRenderer, menu item

**Files:**
- Modify: `MDView/Sources/MDView/main.swift`

- [ ] **Step 1: Delete the old `css` global**

Remove the `// MARK: - CSS Styles` section and the entire `let css = """..."""` literal (lines 62–140).

- [ ] **Step 2: Update `DocumentWindow.loadFile` to use HTMLDocument**

Replace the `let html = MarkdownParser.toHTML(content)` + `let fullHTML = """..."""` block with:

```swift
        let fullHTML = HTMLDocument.makePage(markdown: content)
```

(The temp-file write and `webView.loadFileURL` code below it stay unchanged.)

- [ ] **Step 3: Update `showWelcome` and `showError`**

In both, replace `<style>\(css)</style>` with `<style>\(HTMLDocument.lightCSS)</style>`.

- [ ] **Step 4: Add PrintRenderer class** (place between DocumentWindow and AppDelegate)

```swift
// MARK: - Print Renderer (offscreen WKWebView -> PDF -> Preview)
class PrintRenderer: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let tempHTMLFile: URL
    private let pdfURL: URL
    private let done: () -> Void

    init(htmlFile: URL, readAccess: URL, pdfURL: URL, done: @escaping () -> Void) {
        self.tempHTMLFile = htmlFile
        self.pdfURL = pdfURL
        self.done = done
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 816, height: 1056))
        super.init()
        webView.navigationDelegate = self
        webView.loadFileURL(htmlFile, allowingReadAccessTo: readAccess)
    }

    deinit {
        try? FileManager.default.removeItem(at: tempHTMLFile)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.createPDF { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                do {
                    try data.write(to: self.pdfURL, options: .atomic)
                    NSWorkspace.shared.open(self.pdfURL)
                } catch {
                    self.showAlert("Could not save PDF file.")
                }
            case .failure:
                self.showAlert("Could not generate PDF.")
            }
            self.finish()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showAlert("Could not render document for printing.")
        finish()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showAlert("Could not render document for printing.")
        finish()
    }

    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Print Failed"
        alert.informativeText = message
        alert.runModal()
    }

    private func finish() {
        webView.navigationDelegate = nil
        webView.stopLoading()
        done()
    }
}
```

- [ ] **Step 5: Add `printDocument()` to DocumentWindow**

Add property `var printRenderer: PrintRenderer?` and:

```swift
    func printDocument() {
        guard let file = currentFile else { return }

        guard let content = try? String(contentsOf: file, encoding: .utf8) else {
            let alert = NSAlert()
            alert.messageText = "Print Failed"
            alert.informativeText = "Could not read file."
            alert.runModal()
            return
        }

        let html = HTMLDocument.makePrintPage(markdown: content)
        let parentDir = file.deletingLastPathComponent()
        let tempFile = parentDir.appendingPathComponent(".mdview_print_\(ProcessInfo.processInfo.processIdentifier)_\(ObjectIdentifier(self).hashValue).html")
        guard let _ = try? html.write(to: tempFile, atomically: true, encoding: .utf8) else {
            let alert = NSAlert()
            alert.messageText = "Print Failed"
            alert.informativeText = "Could not write temporary file."
            alert.runModal()
            return
        }

        let pdfURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MDView-\(file.deletingPathExtension().lastPathComponent).pdf")
        printRenderer = PrintRenderer(htmlFile: tempFile, readAccess: parentDir, pdfURL: pdfURL) { [weak self] in
            self?.printRenderer = nil
        }
    }
```

- [ ] **Step 6: Add menu item and AppDelegate action**

In `setupMenus()`, after the Reload item, add:

```swift
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Print...", action: #selector(printDocument), keyEquivalent: "p")
```

Add to AppDelegate:

```swift
    @objc func printDocument() {
        guard let keyWindow = NSApp.keyWindow,
              let docWindow = windows.first(where: { $0.window === keyWindow }),
              docWindow.currentFile != nil else {
            let alert = NSAlert()
            alert.messageText = "Nothing to Print"
            alert.informativeText = "Open a Markdown file first."
            alert.runModal()
            return
        }
        docWindow.printDocument()
    }
```

- [ ] **Step 7: Build**

Run: `make build`
Expected: build succeeds

---

### Task 4: Docs + final verification

**Files:**
- Modify: `CLAUDE.md` (Architecture section: CSS now lives in `MarkdownParserLib/HTMLDocument.swift` as `lightCSS`/`darkCSS`/`screenCSS`, assembled via `HTMLDocument.makePage`/`makePrintPage`; mention printing via offscreen WKWebView → PDF → Preview)
- Modify: `README.md` (add Print… / Cmd+P to feature/usage list if one exists — check first, keep it minimal)

- [ ] **Step 1:** Update `CLAUDE.md` and `README.md` as above.
- [ ] **Step 2:** Run full test suite: `cd MDView && swift test` — all pass.
- [ ] **Step 3:** `make bundle` succeeds.
- [ ] **Step 4:** Manual smoke (reported for user to confirm): open a markdown file with tables/code/images, press Cmd+P → PDF opens in Preview, light-styled, in both system light and dark mode.

===== TASK 1 OUTPUT: MDView/Sources/MarkdownParserLib/HTMLDocument.swift =====
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
