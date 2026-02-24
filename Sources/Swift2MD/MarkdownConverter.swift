import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Main entry point for converting files to Markdown using Workers AI.
public struct MarkdownConverter: Sendable {
    private let client: CloudflareClient
    private let downloadSession: URLSession

    /// Creates a converter with required Cloudflare credentials and options.
    public init(credentials: CloudflareCredentials, options: ConvertOptions = .init()) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = options.timeout.timeInterval
        configuration.timeoutIntervalForResource = options.timeout.timeInterval
        let session = URLSession(configuration: configuration)

        self.client = CloudflareClient(
            credentials: credentials,
            session: session,
            timeout: options.timeout,
            maxRetryCount: options.maxRetryCount,
            retryBaseDelay: options.retryBaseDelay
        )
        self.downloadSession = session
    }

    init(client: CloudflareClient, downloadSession: URLSession) {
        self.client = client
        self.downloadSession = downloadSession
    }

    /// Downloads a remote resource and converts it to Markdown.
    public func convert(_ url: URL) async throws -> ConversionResult {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await downloadSession.data(from: url)
        } catch {
            throw Swift2MDError.networkError(underlying: error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Swift2MDError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        let filename = inferredFilename(from: url, response: response)
        return try await convert(data, filename: filename)
    }

    /// Converts raw file data using the provided filename for format detection.
    public func convert(_ data: Data, filename: String) async throws -> ConversionResult {
        guard SupportedFormat(filename: filename) != nil else {
            throw Swift2MDError.unsupportedFormat(filename)
        }

        let results = try await client.toMarkdown(files: [(data: data, filename: filename)])
        guard let first = results.first else {
            throw Swift2MDError.invalidResponse
        }
        return first
    }

    /// Reads a local file and converts it to Markdown.
    public func convert(fileAt url: URL) async throws -> ConversionResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw Swift2MDError.fileReadError(underlying: error)
        }

        return try await convert(data, filename: url.lastPathComponent)
    }

    /// Converts multiple files in one API request.
    public func convert(_ files: [(data: Data, filename: String)]) async throws -> [ConversionResult] {
        for file in files {
            guard SupportedFormat(filename: file.filename) != nil else {
                throw Swift2MDError.unsupportedFormat(file.filename)
            }
        }
        return try await client.toMarkdown(files: files)
    }

    private func inferredFilename(from url: URL, response: URLResponse) -> String {
        let candidate = url.lastPathComponent
        if SupportedFormat(filename: candidate) != nil {
            return candidate
        }

        if let mimeType = response.mimeType,
           let format = SupportedFormat(mimeType: mimeType) {
            return "downloaded.\(format.fileExtension)"
        }

        return candidate
    }
}
