import CoreGraphics
import Foundation

/// Splits tall single-page PDFs (as produced by `WKWebView.createPDF`) into
/// fixed-size pages suitable for printing. Vector content (text) is preserved;
/// each output page shows a horizontal slice of the source, scaled so the
/// source width fills the page width.
public enum PDFPaginator {

    /// Paginates `pdfData` into pages of `pageSize` (default: US Letter, 612x792 pt).
    /// Returns nil if `pdfData` is not a readable PDF.
    public static func paginate(pdfData: Data, pageSize: CGSize = CGSize(width: 612, height: 792)) -> Data? {
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let document = CGPDFDocument(provider),
              document.numberOfPages > 0 else {
            return nil
        }

        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            return nil
        }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        for pageIndex in 1...document.numberOfPages {
            guard let page = document.page(at: pageIndex) else { continue }
            let box = page.getBoxRect(.mediaBox)
            let scale = pageSize.width / box.width
            let sourcePerPage = pageSize.height / scale
            let slices = max(1, Int(ceil(box.height / sourcePerPage)))

            // PDF y-axis points up: slice 0 shows the TOP strip of the source page.
            for slice in 0..<slices {
                context.beginPDFPage(nil)
                context.saveGState()
                context.clip(to: CGRect(origin: .zero, size: pageSize))
                context.scaleBy(x: scale, y: scale)
                context.translateBy(
                    x: -box.minX,
                    y: CGFloat(slice + 1) * sourcePerPage - box.maxY
                )
                context.drawPDFPage(page)
                context.restoreGState()
                context.endPDFPage()
            }
        }

        context.closePDF()
        return output as Data
    }
}
