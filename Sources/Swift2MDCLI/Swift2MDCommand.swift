import ArgumentParser
import Foundation
import Swift2MD

@main
struct Swift2MDCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift2md",
        abstract: "Convert a URL or local file into Markdown using Cloudflare Workers AI.",
        discussion: "Credentials can be provided via --account-id/--api-token or CLOUDFLARE_ACCOUNT_ID/CLOUDFLARE_API_TOKEN."
    )

    @Argument(help: "Input URL (http/https) or local file path.")
    var input: String

    @Option(name: .long, help: "Cloudflare account ID. Falls back to CLOUDFLARE_ACCOUNT_ID.")
    var accountId: String?

    @Option(name: .long, help: "Cloudflare API token. Falls back to CLOUDFLARE_API_TOKEN.")
    var apiToken: String?

    @Option(name: [.short, .long], help: "Output file path for markdown. Defaults to stdout.")
    var output: String?

    mutating func run() async throws {
        let environment = ProcessInfo.processInfo.environment

        guard let resolvedAccountId = resolvedCredential(primary: accountId, env: environment["CLOUDFLARE_ACCOUNT_ID"]) else {
            throw ValidationError("Missing Cloudflare account ID. Use --account-id or set CLOUDFLARE_ACCOUNT_ID.")
        }

        guard let resolvedApiToken = resolvedCredential(primary: apiToken, env: environment["CLOUDFLARE_API_TOKEN"]) else {
            throw ValidationError("Missing Cloudflare API token. Use --api-token or set CLOUDFLARE_API_TOKEN.")
        }

        let credentials = CloudflareCredentials(accountId: resolvedAccountId, apiToken: resolvedApiToken)
        let converter = MarkdownConverter(credentials: credentials)

        let result: ConversionResult
        if let remoteURL = remoteURL(from: input) {
            result = try await converter.convert(remoteURL)
        } else {
            let filePath = NSString(string: input).expandingTildeInPath
            result = try await converter.convert(fileAt: URL(fileURLWithPath: filePath))
        }

        if let output {
            let outputPath = NSString(string: output).expandingTildeInPath
            try result.markdown.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print(outputPath)
            return
        }

        FileHandle.standardOutput.write(Data(result.markdown.utf8))
        if !result.markdown.hasSuffix("\n") {
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    private func resolvedCredential(primary: String?, env: String?) -> String? {
        let candidate = primary ?? env
        guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private func remoteURL(from rawInput: String) -> URL? {
        guard let url = URL(string: rawInput),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
}
