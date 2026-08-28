import AppKit
import WebKit
import UniformTypeIdentifiers
import MarkdownParserLib

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

// MARK: - Document Window (supports multiple windows)
class DocumentWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    let webView: WKWebView
    var currentFile: URL?
    var fileDescriptor: Int32 = -1
    var fileWatcher: DispatchSourceFileSystemObject?
    var printRenderer: PrintRenderer?

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

        let fullHTML = HTMLDocument.makePage(markdown: content)

        webView.loadHTMLString(fullHTML, baseURL: url.deletingLastPathComponent())
        startWatching(url)
    }

    func startWatching(_ url: URL) {
        stopWatching()

        fileDescriptor = Darwin.open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        // Capture the file descriptor value directly to avoid accessing self in cancel handler
        let fd = fileDescriptor

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
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

        // Capture fd directly - don't access self in cancel handler to avoid crashes on exit
        source.setCancelHandler {
            if fd >= 0 {
                Darwin.close(fd)
            }
        }

        source.resume()
        fileWatcher = source
    }

    func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
        fileDescriptor = -1
    }

    func reload() {
        if let file = currentFile {
            loadFile(file)
        }
    }

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

    func showWelcome() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>\(HTMLDocument.lightCSS)</style></head>
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
        <head><meta charset="utf-8"><style>\(HTMLDocument.lightCSS)</style></head>
        <body><h1>Error</h1><p>\(message)</p></body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    func windowWillClose(_ notification: Notification) {
        stopWatching()
        webView.stopLoading()
        webView.removeFromSuperview()
        window.delegate = nil
        AppDelegate.shared.windows.removeAll { $0 === self }
    }
}

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
                    // createPDF returns one tall single page; slice it into
                    // letter pages so it prints without Preview scaling it down.
                    let output = PDFPaginator.paginate(pdfData: data) ?? data
                    try output.write(to: self.pdfURL, options: .atomic)
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
        // Check if file is already open - bring existing window to front
        if let existingWindow = windows.first(where: { $0.currentFile == url }) {
            existingWindow.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
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
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Print...", action: #selector(printDocument), keyEquivalent: "p")
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

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up all file watchers before exit
        for docWindow in windows {
            docWindow.stopWatching()
        }
        windows.removeAll()
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
