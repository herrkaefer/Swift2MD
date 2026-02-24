import Foundation

/// Cloudflare account credentials required for Workers AI requests.
public struct CloudflareCredentials: Sendable {
    /// Cloudflare account identifier used in API endpoint paths.
    public let accountId: String
    /// API token with permission to call Workers AI.
    public let apiToken: String

    /// Creates a credential container for API requests.
    public init(accountId: String, apiToken: String) {
        self.accountId = accountId
        self.apiToken = apiToken
    }
}

/// Converter runtime options.
public struct ConvertOptions: Sendable {
    /// Timeout applied to HTTP requests and resource downloads.
    public var timeout: Duration

    /// Creates conversion options with an optional request timeout.
    public init(timeout: Duration = .seconds(60)) {
        self.timeout = timeout
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let parts = components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1_000_000_000_000_000_000
    }
}
