import Foundation

/// Backward-compatible alias for the main converter type.
public typealias SwiftToMarkdownConverter = MarkdownConverter

public extension MarkdownConverter {
    /// Convenience factory for creating a converter directly from raw credential values.
    static func withCloudflare(
        accountId: String,
        apiToken: String,
        timeout: Duration = .seconds(60)
    ) -> MarkdownConverter {
        let credentials = CloudflareCredentials(accountId: accountId, apiToken: apiToken)
        let options = ConvertOptions(timeout: timeout)
        return MarkdownConverter(credentials: credentials, options: options)
    }
}
