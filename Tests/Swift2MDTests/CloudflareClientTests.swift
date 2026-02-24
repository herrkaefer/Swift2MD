import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import Swift2MD

final class CloudflareClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testToMarkdownSuccessDecodesDataAsMarkdown() async throws {
        let session = makeMockedSession()
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.absoluteString.contains("/ai/tomarkdown") == true)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
            let json = """
            {
              "result": [
                {
                  "name": "file.pdf",
                  "mimeType": "application/pdf",
                  "tokens": 12,
                  "data": "# Markdown"
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

        let credentials = CloudflareCredentials(accountId: "acc", apiToken: "token")
        let client = CloudflareClient(credentials: credentials, session: session, timeout: .seconds(10))

        let results = try await client.toMarkdown(files: [(data: Data([0x01]), filename: "file.pdf")])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.markdown, "# Markdown")
    }

    func testToMarkdownReturnsEmptyArrayForEmptyInput() async throws {
        let session = makeMockedSession()
        let credentials = CloudflareCredentials(accountId: "acc", apiToken: "token")
        let client = CloudflareClient(credentials: credentials, session: session, timeout: .seconds(10))

        let results = try await client.toMarkdown(files: [])
        XCTAssertEqual(results, [])
    }

    func testToMarkdownSupportsConcurrentRequests() async throws {
        let session = makeMockedSession()
        let lock = NSLock()
        var callCount = 0

        MockURLProtocol.requestHandler = { request in
            lock.lock()
            callCount += 1
            lock.unlock()

            let json = """
            {
              "result": [
                {
                  "name": "file.pdf",
                  "mimeType": "application/pdf",
                  "tokens": 1,
                  "data": "# Markdown"
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

        let credentials = CloudflareCredentials(accountId: "acc", apiToken: "token")
        let client = CloudflareClient(credentials: credentials, session: session, timeout: .seconds(10))

        let results = try await withThrowingTaskGroup(of: ConversionResult.self) { group in
            for index in 0..<12 {
                group.addTask {
                    let response = try await client.toMarkdown(
                        files: [(data: Data([0x01]), filename: "file\(index).pdf")]
                    )
                    return try XCTUnwrap(response.first)
                }
            }

            var collected: [ConversionResult] = []
            for try await value in group {
                collected.append(value)
            }
            return collected
        }

        XCTAssertEqual(results.count, 12)
        XCTAssertEqual(callCount, 12)
        XCTAssertTrue(results.allSatisfy { $0.markdown == "# Markdown" })
    }

    func testToMarkdownRetriesOn429ThenSucceeds() async throws {
        let session = makeMockedSession()
        let lock = NSLock()
        var callCount = 0

        MockURLProtocol.requestHandler = { request in
            lock.lock()
            callCount += 1
            let current = callCount
            lock.unlock()

            if current == 1 {
                let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
                return (response, Data("rate limited".utf8))
            }

            let json = """
            {
              "result": [
                {
                  "name": "file.pdf",
                  "mimeType": "application/pdf",
                  "tokens": 2,
                  "data": "# Retry Success"
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

        let credentials = CloudflareCredentials(accountId: "acc", apiToken: "token")
        let client = CloudflareClient(
            credentials: credentials,
            session: session,
            timeout: .seconds(10),
            maxRetryCount: 2,
            retryBaseDelay: .milliseconds(1)
        )

        let results = try await client.toMarkdown(files: [(data: Data([0x01]), filename: "file.pdf")])
        XCTAssertEqual(results.first?.markdown, "# Retry Success")
        XCTAssertEqual(callCount, 2)
    }

    func testToMarkdownRetriesNetworkErrorThenSucceeds() async throws {
        let session = makeMockedSession()
        let lock = NSLock()
        var callCount = 0

        MockURLProtocol.requestHandler = { request in
            lock.lock()
            callCount += 1
            let current = callCount
            lock.unlock()

            if current == 1 {
                throw URLError(.timedOut)
            }

            let json = """
            {
              "result": [
                {
                  "name": "file.pdf",
                  "mimeType": "application/pdf",
                  "tokens": 2,
                  "data": "# Retry Success"
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

        let credentials = CloudflareCredentials(accountId: "acc", apiToken: "token")
        let client = CloudflareClient(
            credentials: credentials,
            session: session,
            timeout: .seconds(10),
            maxRetryCount: 2,
            retryBaseDelay: .milliseconds(1)
        )

        let results = try await client.toMarkdown(files: [(data: Data([0x01]), filename: "file.pdf")])
        XCTAssertEqual(results.first?.markdown, "# Retry Success")
        XCTAssertEqual(callCount, 2)
    }

    func testToMarkdownRespectsRetryLimit() async {
        let session = makeMockedSession()
        let lock = NSLock()
        var callCount = 0

        MockURLProtocol.requestHandler = { request in
            lock.lock()
            callCount += 1
            lock.unlock()

            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data("service unavailable".utf8))
        }

        let credentials = CloudflareCredentials(accountId: "acc", apiToken: "token")
        let client = CloudflareClient(
            credentials: credentials,
            session: session,
            timeout: .seconds(10),
            maxRetryCount: 1,
            retryBaseDelay: .milliseconds(1)
        )

        do {
            _ = try await client.toMarkdown(files: [(data: Data([0x01]), filename: "file.pdf")])
            XCTFail("Expected httpError")
        } catch let error as Swift2MDError {
            guard case .httpError(let statusCode, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(statusCode, 503)
            XCTAssertEqual(callCount, 2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testToMarkdownThrowsHTTPError() async {
        let session = makeMockedSession()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data("forbidden".utf8))
        }

        let credentials = CloudflareCredentials(accountId: "acc", apiToken: "token")
        let client = CloudflareClient(credentials: credentials, session: session, timeout: .seconds(10))

        do {
            _ = try await client.toMarkdown(files: [(data: Data([0x01]), filename: "file.pdf")])
            XCTFail("Expected httpError")
        } catch let error as Swift2MDError {
            guard case .httpError(let statusCode, let body) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(statusCode, 403)
            XCTAssertTrue(body.contains("forbidden"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testToMarkdownThrowsAPIErrorWhenSuccessFalse() async {
        let session = makeMockedSession()
        MockURLProtocol.requestHandler = { request in
            let json = """
            {
              "result": [],
              "success": false,
              "errors": [{"message": "invalid token"}],
              "messages": []
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let credentials = CloudflareCredentials(accountId: "acc", apiToken: "token")
        let client = CloudflareClient(credentials: credentials, session: session, timeout: .seconds(10))

        do {
            _ = try await client.toMarkdown(files: [(data: Data([0x01]), filename: "file.pdf")])
            XCTFail("Expected apiError")
        } catch let error as Swift2MDError {
            guard case .apiError(let messages) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(messages, ["invalid token"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeMockedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
