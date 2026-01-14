# MDView

A lightweight, fast Markdown viewer for macOS.

## Features

- Native Swift/AppKit app
- GitHub-flavored Markdown styling (including tables)
- Dark mode support
- Fast startup and rendering
- Auto-reload on file save
- No external dependencies

## Installation

```bash
make install
```

This builds the app and copies it to `/Applications/`.

## Usage

### Open from Finder
Right-click a `.md` file → Open With → MDView

To set as default: Right-click → Get Info → Open with → MDView → Change All

### Command line
```bash
open -a MDView file.md
```

Or add to PATH:
```bash
ln -s /Applications/MDView.app/Contents/MacOS/MDView /usr/local/bin/mdview
mdview file.md
```

## Build

```bash
make build    # Build only
make bundle   # Create .app bundle
make install  # Install to /Applications
make clean    # Clean build artifacts
```

## Requirements

- macOS 12.0+
- Swift 5.9+
