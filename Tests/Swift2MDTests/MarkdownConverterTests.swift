import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import Swift2MD

final class MarkdownConverterTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testConvertDataThrowsUnsupportedFormat() async {
        let converter = makeConverter()

        do {
            _ = try await converter.convert(Data("hello".utf8), filename: "note.txt")
            XCTFail("Expected unsupportedFormat")
        } catch let error as Swift2MDError {
            guard case .unsupportedFormat(let value) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(value, "note.txt")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConvertURLDownloadsAndConverts() async throws {
        let converter = makeConverter()

        MockURLProtocol.requestHandler = { request in
            if request.url?.host == "example.com" {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/pdf"]
                )!
                return (response, Data("%PDF-1.4".utf8))
            }

            XCTAssertTrue(request.url?.absoluteString.contains("/ai/tomarkdown") == true)
            let json = """
            {
              "result": [
                {
                  "name": "downloaded.pdf",
                  "mimeType": "application/pdf",
                  "tokens": 9,
                  "data": "# Converted"
                }
              ],
              "success": true,
              "errors": [],
              "messages": []
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let result = try await converter.convert(URL(string: "https://example.com/document")!)
        XCTAssertEqual(result.name, "downloaded.pdf")
        XCTAssertEqual(result.markdown, "# Converted")
    }

    func testConvertFileAtURL() async throws {
        let converter = makeConverter()
        MockURLProtocol.requestHandler = { request in
            let json = """
            {
              "result": [
                {
                  "name": "file.pdf",
                  "mimeType": "application/pdf",
                  "tokens": 3,
                  "data": "# File"
                }
              ],
              "success": true,
              "errors": [],
              "messages": []
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        try Data("pdfdata".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = try await converter.convert(fileAt: tempURL)
        XCTAssertEqual(result.markdown, "# File")
    }

    func testConvertFileAtURLThrowsFileReadError() async {
        let converter = makeConverter()
        let missingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")

        do {
            _ = try await converter.convert(fileAt: missingURL)
            XCTFail("Expected fileReadError")
        } catch let error as Swift2MDError {
            guard case .fileReadError = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConvertEmptyBatchReturnsEmptyWithoutNetwork() async throws {
        let converter = makeConverter()
        let results = try await converter.convert([])
        XCTAssertEqual(results, [])
    }

    func testIntegrationWithRealCloudflareWhenConfigured() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SWIFT2MD_RUN_INTEGRATION"] == "1" else {
            throw XCTSkip("Set SWIFT2MD_RUN_INTEGRATION=1 to run integration test")
        }

        guard let accountId = env["CLOUDFLARE_ACCOUNT_ID"],
              let apiToken = env["CLOUDFLARE_API_TOKEN"],
              let filePath = env["SWIFT2MD_INTEGRATION_FILE"] else {
            throw XCTSkip("Missing CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN, or SWIFT2MD_INTEGRATION_FILE")
        }

        let credentials = CloudflareCredentials(accountId: accountId, apiToken: apiToken)
        let converter = MarkdownConverter(credentials: credentials)
        let result = try await converter.convert(fileAt: URL(fileURLWithPath: filePath))

        XCTAssertFalse(result.markdown.isEmpty)
    }

    private func makeConverter() -> MarkdownConverter {
        let session = makeMockedSession()
        let credentials = CloudflareCredentials(accountId: "acc", apiToken: "token")
        let client = CloudflareClient(credentials: credentials, session: session, timeout: .seconds(10))
        return MarkdownConverter(client: client, downloadSession: session)
    }

    private func makeMockedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
