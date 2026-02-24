import Foundation

/// Errors produced by Swift2MD conversion APIs.
public enum Swift2MDError: LocalizedError {
    /// The provided filename extension is not supported by Workers AI toMarkdown.
    case unsupportedFormat(String)
    /// Network transport failed while downloading or calling the API.
    case networkError(underlying: Error)
    /// Local file I/O failed while reading input data.
    case fileReadError(underlying: Error)
    /// The server returned a non-2xx HTTP status.
    case httpError(statusCode: Int, body: String)
    /// Workers AI responded with `success: false`.
    case apiError(messages: [String])
    /// Response payload could not be parsed or was missing required data.
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let value):
            return "Unsupported format: \(value)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .fileReadError(let underlying):
            return "File read error: \(underlying.localizedDescription)"
        case .httpError(let statusCode, let body):
            return "HTTP error \(statusCode): \(body)"
        case .apiError(let messages):
            if messages.isEmpty { return "Workers AI API returned an error." }
            return "Workers AI API error: \(messages.joined(separator: "; "))"
        case .invalidResponse:
            return "Invalid response from Workers AI API."
        }
    }
}
