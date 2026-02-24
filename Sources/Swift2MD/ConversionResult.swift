import Foundation

/// One converted file returned by Workers AI.
public struct ConversionResult: Sendable, Codable, Equatable {
    /// Original file name reported by the API.
    public let name: String
    /// MIME type detected by the API.
    public let mimeType: String
    /// Token count consumed for the conversion.
    public let tokens: Int
    /// Markdown output content (mapped from API `data` field).
    public let markdown: String

    /// Creates a conversion result value.
    public init(name: String, mimeType: String, tokens: Int, markdown: String) {
        self.name = name
        self.mimeType = mimeType
        self.tokens = tokens
        self.markdown = markdown
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case mimeType
        case tokens
        case markdown = "data"
    }
}
