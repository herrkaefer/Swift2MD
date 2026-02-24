# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

## [Unreleased]

### Added
- Configurable retry policy in `ConvertOptions` (`maxRetryCount`, `retryBaseDelay`).
- Exponential backoff retry handling for Workers AI calls on transient network errors and HTTP `429/5xx`.
- CI workflow (`.github/workflows/ci.yml`) to build and test on macOS and Linux.

### Changed
- `MarkdownConverter` now passes retry configuration to `CloudflareClient`.
- README now includes CI badge and retry behavior notes.

## [0.1.0] - 2026-02-24

### Added
- Initial Swift2MD library and CLI implementation.
- Workers AI `toMarkdown()` client with multipart upload support.
- Strongly typed format detection and API response models.
- Unit test suite (format parsing, multipart, client, converter, integration test gate).
- README documentation and MIT license.
