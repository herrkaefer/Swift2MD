# Swift2MD

[![](https://img.shields.io/github/v/tag/herrkaefer/Swift2MD?label=version)](https://github.com/herrkaefer/Swift2MD/tags)
[![CI](https://github.com/herrkaefer/Swift2MD/actions/workflows/ci.yml/badge.svg)](https://github.com/herrkaefer/Swift2MD/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fherrkaefer%2FSwift2MD%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/herrkaefer/Swift2MD)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fherrkaefer%2FSwift2MD%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/herrkaefer/Swift2MD)
[![](https://img.shields.io/badge/platforms-macOS%2013%2B%20%7C%20iOS%2016%2B-0A84FF)](https://swiftpackageindex.com/herrkaefer/Swift2MD)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Swift2MD is a lightweight Swift package and CLI for converting URLs or local documents into Markdown using [**Cloudflare Workers AI `toMarkdown()`**](https://developers.cloudflare.com/workers-ai/features/markdown-conversion/).

## What It Does

- Provides a Swift-native API (`async/await`, strong types) for document-to-Markdown conversion.
- Provides a CLI for quick manual testing:
  - `swift run swift2md <url-or-file>`
- Uses Cloudflare Workers AI for all conversion work.

## Requirements

- Swift 5.9+
- A Cloudflare account
- A Cloudflare API token that can call Workers AI

## Reliability Defaults

- API calls retry up to `2` times on retryable failures (`429`, `5xx`, and transient network errors).
- Backoff is exponential with a default base delay of `300ms`.
- You can override both values with `ConvertOptions`.

## Supported Input Formats

`pdf`, `jpeg/jpg`, `png`, `webp`, `svg`, `html/htm`, `xml`, `csv`, `docx`, `xlsx`, `xlsm`, `xlsb`, `xls`, `et`, `ods`, `odt`, `numbers`

For the official and most up-to-date list, see:
https://developers.cloudflare.com/workers-ai/features/markdown-conversion/#supported-formats

## Install (Swift Package)

In `Package.swift`:

```swift
.package(url: "https://github.com/herrkaefer/Swift2MD.git", from: "0.1.0")
```

Then add to your target dependencies:

```swift
.product(name: "Swift2MD", package: "Swift2MD")
```

## Library Usage

```swift
import Swift2MD

let credentials = CloudflareCredentials(
    accountId: "<CLOUDFLARE_ACCOUNT_ID>",
    apiToken: "<CLOUDFLARE_API_TOKEN>"
)

let converter = MarkdownConverter(
    credentials: credentials,
    options: ConvertOptions(
        timeout: .seconds(60),
        maxRetryCount: 2,
        retryBaseDelay: .milliseconds(300)
    )
)

// Convert remote URL
let urlResult = try await converter.convert(URL(string: "https://example.com/file.pdf")!)
print(urlResult.markdown)

// Convert local file
let fileResult = try await converter.convert(fileAt: URL(fileURLWithPath: "/path/to/file.pdf"))
print(fileResult.markdown)

// Convert batch (library API)
let fileData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/file.pdf"))
let batch = try await converter.convert([
    (data: fileData, filename: "a.pdf"),
    (data: fileData, filename: "b.pdf")
])
print(batch.count)
```

## CLI Usage

Build:

```bash
swift build
```

Set credentials (recommended):

```bash
export CLOUDFLARE_ACCOUNT_ID="your_account_id"
export CLOUDFLARE_API_TOKEN="your_api_token"
```

Run:

```bash
# URL input
swift run swift2md https://example.com/file.pdf

# Local file input
swift run swift2md /path/to/file.pdf

# Write markdown to a file
swift run swift2md /path/to/file.pdf -o output.md
```

Or pass credentials inline:

```bash
swift run swift2md /path/to/file.pdf --account-id <id> --api-token <token>
```

## Limits and Notes

- **Credentials are required** for all conversions.
- **CLI currently accepts one input at a time** (`<input>`).
- **Output quality depends on input complexity**; post-editing may still be needed.
- **Image conversion may use additional Workers AI models** (object detection/summarization), which can affect usage/cost.
- **Rate limits**:
  - As of **February 24, 2026**, the Markdown Conversion page does not publish a dedicated per-endpoint `toMarkdown` rate-limit value.
  - Workers AI platform limits are documented here: https://developers.cloudflare.com/workers-ai/platform/limits/
  - Pricing and allocation notes are here: https://developers.cloudflare.com/workers-ai/features/markdown-conversion/#pricing

## Error Types

- `unsupportedFormat`
- `fileReadError`
- `networkError`
- `httpError`
- `apiError`
- `invalidResponse`

## Development

```bash
swift build
swift test
swift run swift2md --help
```

See [CHANGELOG.md](CHANGELOG.md) for release history.

Integration test is opt-in with environment variables:

- `SWIFT2MD_RUN_INTEGRATION=1`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`
- `SWIFT2MD_INTEGRATION_FILE`

## Swift Package Index Submission Checklist

Before submitting to SPI, verify:

- The repository is publicly accessible.
- The package URL uses a full Git URL with protocol and `.git` suffix, for example:
  - `https://github.com/herrkaefer/Swift2MD.git`
- At least one semantic version tag exists (this repo includes `v0.1.0`).
- `swift package dump-package` succeeds.
- `swift build` succeeds.
