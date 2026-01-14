# MDView - Project Plan

## Overview

A lightweight, native macOS Markdown viewer focused on speed and simplicity.

## Goals

1. **Fast startup** - Native Swift, no heavy frameworks
2. **Simple** - Single purpose, minimal UI
3. **Pretty rendering** - GitHub-style CSS with dark mode

## Architecture

- **AppKit** for window management
- **WKWebView** for HTML rendering
- **Custom Markdown parser** - regex-based, no dependencies
- **Swift Package Manager** for build

## Current Status

- [x] Basic Markdown parsing (headers, bold, italic, code, links, lists)
- [x] GitHub-style CSS with dark mode support
- [x] File opening (menu, command line, file association)
- [x] Proper .app bundle with Info.plist
- [x] Makefile for build/install
- [x] Table support in Markdown parser
- [x] File watching for auto-reload on save
- [x] Prompt to set as default app for .md files

## Future Enhancements (if needed)

- [ ] Print support
- [ ] Syntax highlighting in code blocks
