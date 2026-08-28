# MDView

A lightweight macOS Markdown viewer built with Swift/AppKit/WebKit.

## Layout

- SwiftPM package in `MDView/`
- App sources: `MDView/Sources/MDView/main.swift`
- Parser library: `MDView/Sources/MarkdownParserLib/`
- Tests: `MDView/Tests/MarkdownParserTests/`

## Build

- `make build` — build the SwiftPM package
- `make bundle` — create `MDView.app`
- `make install` — install to `/Applications`

## Architecture

- CSS and HTML page assembly live in `MarkdownParserLib/HTMLDocument.swift`:
  `lightCSS` / `darkCSS` / `screenCSS`, assembled via
  `HTMLDocument.makePage` / `makePrintPage`.
- Printing renders an offscreen WKWebView, captures it with `createPDF`,
  slices the resulting single tall page into US Letter pages with
  `MarkdownParserLib/PDFPaginator.swift`, and opens the PDF in Preview
  (File → Print…, Cmd+P).
