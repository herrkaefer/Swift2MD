import XCTest
@testable import Swift2MD

final class SupportedFormatTests: XCTestCase {
    func testInitWithFilename() {
        XCTAssertEqual(SupportedFormat(filename: "report.pdf"), .pdf)
        XCTAssertEqual(SupportedFormat(filename: "photo.jpg"), .jpeg)
        XCTAssertEqual(SupportedFormat(filename: "sheet.xlsx"), .xlsx)
    }

    func testInitWithMimeType() {
        XCTAssertEqual(SupportedFormat(mimeType: "application/pdf"), .pdf)
        XCTAssertEqual(SupportedFormat(mimeType: "image/jpeg; charset=utf-8"), .jpeg)
        XCTAssertEqual(SupportedFormat(mimeType: "text/xml"), .xml)
    }

    func testUnsupportedValuesReturnNil() {
        XCTAssertNil(SupportedFormat(filename: "notes.txt"))
        XCTAssertNil(SupportedFormat(mimeType: "text/plain"))
    }

    func testEachCaseHasFileExtension() {
        for format in SupportedFormat.allCases {
            XCTAssertFalse(format.fileExtension.isEmpty)
            XCTAssertFalse(format.mimeType.isEmpty)
        }
    }
}
