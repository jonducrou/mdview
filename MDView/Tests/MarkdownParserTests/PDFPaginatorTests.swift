import XCTest
import PDFKit
@testable import MarkdownParserLib

final class PDFPaginatorTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a single tall-page PDF (like WKWebView.createPDF produces) with a
    /// black marker square near the top of the page and one near the bottom.
    private func makeTallPDF(width: CGFloat = 816, height: CGFloat) -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: width, height: height)
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        let context = CGContext(consumer: consumer, mediaBox: &box, nil)!
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(box)
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        // PDF y-axis points up: document top is near height, bottom is near 0.
        context.fill(CGRect(x: 20, y: height - 60, width: 40, height: 40)) // top marker
        context.fill(CGRect(x: 20, y: 20, width: 40, height: 40))          // bottom marker
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    /// Renders a PDF page at 1x and counts dark pixels in the given band
    /// (coordinates in the 612x792 page space).
    private func darkPixels(in page: PDFPage, band: CGRect) -> Int {
        let size = page.bounds(for: .mediaBox).size
        let width = Int(size.width), height = Int(size.height)
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        page.draw(with: .mediaBox, to: context)

        // Bitmap y=0 is the top row; PDF y=0 is the bottom. Flip the band.
        let flipped = CGRect(
            x: band.minX,
            y: size.height - band.maxY,
            width: band.width,
            height: band.height
        )
        var count = 0
        for row in Int(flipped.minY)..<Int(flipped.maxY) {
            for col in Int(flipped.minX)..<Int(flipped.maxX) {
                let offset = (row * width + col) * 4
                if pixels[offset] < 128 { count += 1 }
            }
        }
        return count
    }

    private let fullWidthBand = CGRect(x: 0, y: 0, width: 612, height: 792)

    // MARK: - Pagination

    func testPaginateSplitsTallPageIntoLetterPages() {
        // 816x4000 source -> scale 612/816 = 0.75 -> 1056 source units per page -> 4 pages
        let output = PDFPaginator.paginate(pdfData: makeTallPDF(height: 4000))
        XCTAssertNotNil(output)
        let doc = PDFDocument(data: output!)!
        XCTAssertEqual(doc.pageCount, 4)
        for i in 0..<doc.pageCount {
            XCTAssertEqual(doc.page(at: i)!.bounds(for: .mediaBox), CGRect(x: 0, y: 0, width: 612, height: 792))
        }
    }

    func testPaginatePreservesContentInOrder() {
        // Height exactly 4 pages (4 x 1056 source units) so the bottom marker
        // lands in the bottom band of the last page.
        let output = PDFPaginator.paginate(pdfData: makeTallPDF(height: 4224))!
        let doc = PDFDocument(data: output)!
        XCTAssertEqual(doc.pageCount, 4)

        let topBand = CGRect(x: 0, y: 692, width: 612, height: 100)
        let bottomBand = CGRect(x: 0, y: 0, width: 612, height: 100)

        let first = doc.page(at: 0)!
        XCTAssertGreaterThan(darkPixels(in: first, band: topBand), 0)
        XCTAssertEqual(darkPixels(in: first, band: bottomBand), 0)

        let last = doc.page(at: doc.pageCount - 1)!
        XCTAssertGreaterThan(darkPixels(in: last, band: bottomBand), 0)
        XCTAssertEqual(darkPixels(in: last, band: topBand), 0)
    }

    func testPaginateShortPDFProducesSinglePage() {
        let output = PDFPaginator.paginate(pdfData: makeTallPDF(height: 500))!
        let doc = PDFDocument(data: output)!
        XCTAssertEqual(doc.pageCount, 1)
        let page = doc.page(at: 0)!
        XCTAssertEqual(page.bounds(for: .mediaBox), CGRect(x: 0, y: 0, width: 612, height: 792))
        // Both markers fit on one page
        XCTAssertGreaterThan(darkPixels(in: page, band: fullWidthBand), 0)
    }

    func testPaginateInvalidDataReturnsNil() {
        XCTAssertNil(PDFPaginator.paginate(pdfData: Data("not a pdf".utf8)))
    }
}
