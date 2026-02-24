import Foundation

/// Backward-compatible alias for the main converter type.
public typealias SwiftToMarkdownConverter = MarkdownConverter

public extension MarkdownConverter {
    /// Convenience factory for creating a converter directly from raw credential values.
    static func withCloudflare(
        accountId: String,
        apiToken: String,
        timeout: Duration = .seconds(60),
        maxRetryCount: Int = 2,
        retryBaseDelay: Duration = .milliseconds(300)
    ) -> MarkdownConverter {
        let credentials = CloudflareCredentials(accountId: accountId, apiToken: apiToken)
        let options = ConvertOptions(
            timeout: timeout,
            maxRetryCount: maxRetryCount,
            retryBaseDelay: retryBaseDelay
        )
        return MarkdownConverter(credentials: credentials, options: options)
    }
}
