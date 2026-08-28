# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

MDView is a lightweight, native macOS Markdown viewer built with Swift/AppKit. It uses WKWebView for rendering and a custom regex-based Markdown parser with zero external dependencies.

## Build & Test Commands

All commands run from the repo root:

```bash
# Build
make build                    # Release build (runs: cd MDView && swift build -c release)
make bundle                   # Create .app bundle
make install                  # Build, bundle, install to /Applications

# Test
cd MDView && swift test       # Run all tests
cd MDView && swift test --filter MarkdownParserTests  # Run parser tests only

# Clean
make clean                    # Remove .app and build artifacts
```

## Architecture

The Swift package (`MDView/Package.swift`) defines three targets:

- **MarkdownParserLib** (`Sources/MarkdownParserLib/`) - Pure Swift library, no AppKit dependency, independently testable. Contains `MarkdownParser.swift` (Markdown→HTML via regex), `HTMLDocument.swift` (CSS + highlight.js page assembly: `lightCSS`/`darkCSS`/`screenCSS`, `makePage`/`makePrintPage`), and `PDFPaginator.swift` (slices single-page PDFs into US Letter pages).
- **MDView** (`Sources/MDView/main.swift`) - The macOS app. Contains AppDelegate, DocumentWindow (NSWindowController-based, multi-window support, file watching via DispatchSource), PrintRenderer, and DefaultAppHandler.
- **MarkdownParserTests** (`Tests/MarkdownParserTests/`) - XCTest suite covering parser features, edge cases, HTMLDocument assembly, and PDF pagination.

**Data flow:** File opened (Finder/CLI/menu) → AppDelegate → DocumentWindow created → MarkdownParser converts MD→HTML → HTMLDocument assembles the page → rendered in WKWebView → DispatchSource watches file for changes → auto-reload on save.

**Printing:** File → Print… (Cmd+P) re-reads the file from disk, assembles a light-styled print page, renders it in an offscreen WKWebView, captures with `createPDF`, slices the resulting single tall page into letter pages via PDFPaginator, and opens the PDF in Preview.

## Key Patterns

- The app uses `DispatchSourceFileSystemObject` for file watching with debounced reload
- Multi-window: each file gets its own `DocumentWindow` (NSWindowController) instance
- Window transform animations are disabled (`animationBehavior = .none`) to prevent `_NSWindowTransformAnimation` dealloc crashes
- All CSS lives in `MarkdownParserLib/HTMLDocument.swift` (GitHub-flavoured styling + dark mode via `prefers-color-scheme`); rendering loads a temp HTML file next to the source so local images resolve
- Code block syntax highlighting uses highlight.js from CDN
- The parser has known limitations documented as test cases (XSS in script tags, markdown inside code blocks, no underscore-style bold/italic)

## Platform

- macOS 12.0+, Swift 5.9+
- `Info.plist` in repo root is copied into the .app bundle during `make bundle`
