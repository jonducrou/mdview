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

- **MarkdownParserLib** (`Sources/MarkdownParserLib/MarkdownParser.swift`) - Pure Swift library that converts Markdown to HTML using regex. No AppKit dependency, independently testable.
- **MDView** (`Sources/MDView/main.swift`) - The macOS app. Contains AppDelegate, DocumentWindow (multi-window support, file watching via DispatchSource), DefaultAppHandler, and embedded GitHub-style CSS with dark mode.
- **MarkdownParserTests** (`Tests/MarkdownParserTests/`) - XCTest suite (~980 lines) covering parser features, edge cases, and known XSS limitations.

**Data flow:** File opened (Finder/CLI/menu) → AppDelegate → DocumentWindow created → MarkdownParser converts MD→HTML → HTML+CSS rendered in WKWebView → DispatchSource watches file for changes → auto-reload on save.

## Key Patterns

- The app uses `DispatchSourceFileSystemObject` for file watching with debounced reload
- Multi-window: each file gets its own `DocumentWindow` instance
- All CSS is embedded inline in `main.swift` (GitHub-flavoured styling + dark mode via `prefers-color-scheme`)
- Code block syntax highlighting uses highlight.js from CDN
- The parser has known limitations documented as test cases (XSS in script tags, markdown inside code blocks, no underscore-style bold/italic)

## Platform

- macOS 12.0+, Swift 5.9+
- `Info.plist` in repo root is copied into the .app bundle during `make bundle`
