import Foundation
import XCTest
@testable import Swift2MD

final class MultipartFormDataTests: XCTestCase {
    func testContentTypeContainsBoundary() {
        let multipart = MultipartFormData(boundary: "test-boundary")
        XCTAssertEqual(multipart.contentType, "multipart/form-data; boundary=test-boundary")
    }

    func testFinalizeBuildsExpectedBody() {
        var multipart = MultipartFormData(boundary: "test-boundary")
        multipart.addFile(data: Data("hello".utf8), name: "files", filename: "doc.pdf", mimeType: "application/pdf")
        let body = multipart.finalize()
        let bodyString = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(bodyString.contains("--test-boundary"))
        XCTAssertTrue(bodyString.contains("Content-Disposition: form-data; name=\"files\"; filename=\"doc.pdf\""))
        XCTAssertTrue(bodyString.contains("Content-Type: application/pdf"))
        XCTAssertTrue(bodyString.contains("hello"))
        XCTAssertTrue(bodyString.contains("--test-boundary--"))
    }
}
