import AppKit
import WebKit
import UniformTypeIdentifiers

// MARK: - Default App Handler
struct DefaultAppHandler {
    static let bundleID = "com.local.mdview"
    static let askedKey = "HasAskedToBeDefault"

    static func isDefault() -> Bool {
        guard let currentHandler = LSCopyDefaultRoleHandlerForContentType(
            "net.daringfireball.markdown" as CFString,
            .viewer
        )?.takeRetainedValue() as String? else {
            return false
        }
        return currentHandler.lowercased() == bundleID.lowercased()
    }

    static func setAsDefault() {
        LSSetDefaultRoleHandlerForContentType(
            "net.daringfireball.markdown" as CFString,
            .viewer,
            bundleID as CFString
        )
        // Also set for .md extension via public.data
        LSSetDefaultRoleHandlerForContentType(
            "public.plain-text" as CFString,
            .viewer,
            bundleID as CFString
        )
    }

    static func hasAskedBefore() -> Bool {
        UserDefaults.standard.bool(forKey: askedKey)
    }

    static func markAsAsked() {
        UserDefaults.standard.set(true, forKey: askedKey)
    }

    static func promptIfNeeded() {
        guard !isDefault() && !hasAskedBefore() else { return }

        let alert = NSAlert()
        alert.messageText = "Set MDView as Default?"
        alert.informativeText = "Would you like to set MDView as the default app for opening Markdown files?"
        alert.addButton(withTitle: "Yes, Set as Default")
        alert.addButton(withTitle: "No Thanks")
        alert.alertStyle = .informational

        let response = alert.runModal()
        markAsAsked()

        if response == .alertFirstButtonReturn {
            setAsDefault()
        }
    }
}

// MARK: - Markdown Parser (lightweight, no dependencies)
struct MarkdownParser {
    static func toHTML(_ markdown: String) -> String {
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

    static func processTables(_ markdown: String) -> String {
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
                    let numLinesToRemove = j - i
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

    static func convertTableToHTML(_ lines: [String]) -> String {
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

    static func escapeHTMLOutsideTags(_ text: String) -> String {
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

// MARK: - CSS Styles
let css = """
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
@media (prefers-color-scheme: dark) {
    body { background: #0d1117; color: #c9d1d9; }
    a { color: #58a6ff; }
    code { background: #161b22; }
    pre { background: #161b22; border-color: #30363d; }
    blockquote { border-color: #30363d; color: #8b949e; }
    hr { background: #30363d; }
    h1, h2 { border-color: #30363d; }
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
@media (prefers-color-scheme: dark) {
    th, td { border-color: #30363d; }
    th { background: #161b22; }
    tr:nth-child(even) { background: #161b22; }
}
"""

// MARK: - Document Window (supports multiple windows)
class DocumentWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    let webView: WKWebView
    var currentFile: URL?
    var fileDescriptor: Int32 = -1
    var fileWatcher: DispatchSourceFileSystemObject?

    override init() {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowWidth: CGFloat = min(1000, screenRect.width * 0.7)
        let windowHeight: CGFloat = min(800, screenRect.height * 0.8)

        // Offset each new window slightly
        let offset = CGFloat(AppDelegate.shared.windows.count * 30)
        let windowRect = NSRect(
            x: (screenRect.width - windowWidth) / 2 + screenRect.minX + offset,
            y: (screenRect.height - windowHeight) / 2 + screenRect.minY - offset,
            width: windowWidth,
            height: windowHeight
        )

        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MDView"
        window.minSize = NSSize(width: 400, height: 300)

        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.autoresizingMask = [.width, .height]

        super.init()

        window.delegate = self
        window.contentView?.addSubview(webView)
        webView.frame = window.contentView!.bounds
        window.makeKeyAndOrderFront(nil)
    }

    func loadFile(_ url: URL) {
        currentFile = url
        window.title = "MDView - \(url.lastPathComponent)"

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            showError("Could not read file")
            return
        }

        let html = MarkdownParser.toHTML(content)
        let fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>\(css)</style>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
        </head>
        <body>\(html)</body>
        <script>hljs.highlightAll();</script>
        </html>
        """

        webView.loadHTMLString(fullHTML, baseURL: url.deletingLastPathComponent())
        startWatching(url)
    }

    func startWatching(_ url: URL) {
        stopWatching()

        fileDescriptor = Darwin.open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self = self, let file = self.currentFile else { return }
            // Debounce: wait for file to finish writing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.loadFile(file)
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                Darwin.close(fd)
            }
            self?.fileDescriptor = -1
        }

        source.resume()
        fileWatcher = source
    }

    func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
    }

    func reload() {
        if let file = currentFile {
            loadFile(file)
        }
    }

    func showWelcome() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>\(css)</style></head>
        <body>
        <h1>MDView</h1>
        <p>A lightweight Markdown viewer.</p>
        <p>Use <strong>File → Open</strong> or <code>Cmd+O</code> to open a Markdown file.</p>
        <p>You can also open files from the command line:</p>
        <pre><code>open -a MDView file.md</code></pre>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    func showError(_ message: String) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>\(css)</style></head>
        <body><h1>Error</h1><p>\(message)</p></body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    func windowWillClose(_ notification: Notification) {
        stopWatching()
        AppDelegate.shared.windows.removeAll { $0 === self }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    var windows: [DocumentWindow] = []
    var pendingURLs: [URL] = []
    var isReady = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupMenus()
        isReady = true

        // Load pending files if opened via file association
        if !pendingURLs.isEmpty {
            for url in pendingURLs {
                openFile(url)
            }
            pendingURLs.removeAll()
        } else {
            // Check for file argument
            let args = CommandLine.arguments
            if args.count > 1 {
                openFile(URL(fileURLWithPath: args[1]))
            } else {
                createNewWindow().showWelcome()
            }
        }

        // Ask to be default (only once, on first launch)
        DispatchQueue.main.async {
            DefaultAppHandler.promptIfNeeded()
        }
    }

    func createNewWindow() -> DocumentWindow {
        let docWindow = DocumentWindow()
        windows.append(docWindow)
        return docWindow
    }

    func openFile(_ url: URL) {
        let docWindow = createNewWindow()
        docWindow.loadFile(url)
    }

    func setupMenus() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About MDView", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit MDView", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open...", action: #selector(openDocument), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Reload", action: #selector(reloadDocument), keyEquivalent: "r")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu (for copy/paste to work)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!, .plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            for url in panel.urls {
                openFile(url)
            }
        }
    }

    @objc func reloadDocument() {
        // Reload the front-most window
        if let keyWindow = NSApp.keyWindow,
           let docWindow = windows.first(where: { $0.window === keyWindow }) {
            docWindow.reload()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if isReady {
            for url in urls {
                openFile(url)
            }
        } else {
            pendingURLs.append(contentsOf: urls)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
