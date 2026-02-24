import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CloudflareClient: Sendable {
    let credentials: CloudflareCredentials
    let session: URLSession
    let timeout: Duration
    let maxRetryCount: Int
    let retryBaseDelay: Duration

    init(
        credentials: CloudflareCredentials,
        session: URLSession = .shared,
        timeout: Duration = .seconds(60),
        maxRetryCount: Int = 2,
        retryBaseDelay: Duration = .milliseconds(300)
    ) {
        self.credentials = credentials
        self.session = session
        self.timeout = timeout
        self.maxRetryCount = max(0, maxRetryCount)
        self.retryBaseDelay = retryBaseDelay
    }

    func toMarkdown(files: [(data: Data, filename: String)]) async throws -> [ConversionResult] {
        guard !files.isEmpty else { return [] }

        var multipart = MultipartFormData()
        for file in files {
            guard let format = SupportedFormat(filename: file.filename) else {
                throw Swift2MDError.unsupportedFormat(file.filename)
            }
            multipart.addFile(data: file.data, name: "files", filename: file.filename, mimeType: format.mimeType)
        }

        let endpoint = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(credentials.accountId)/ai/tomarkdown")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout.timeInterval
        request.setValue("Bearer \(credentials.apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = multipart.finalize()

        var attempt = 0

        while true {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw Swift2MDError.invalidResponse
                }

                let responseBody = String(data: data, encoding: .utf8) ?? ""
                guard (200...299).contains(httpResponse.statusCode) else {
                    if shouldRetry(statusCode: httpResponse.statusCode, attempt: attempt) {
                        throw RetryableRequestError()
                    }
                    throw Swift2MDError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
                }

                do {
                    let decoded = try JSONDecoder().decode(APIEnvelope.self, from: data)
                    guard decoded.success else {
                        let messages = decoded.errors.map(\.message) + decoded.messages.map(\.message)
                        throw Swift2MDError.apiError(messages: messages)
                    }
                    return decoded.result
                } catch let error as Swift2MDError {
                    throw error
                } catch {
                    throw Swift2MDError.invalidResponse
                }
            } catch is RetryableRequestError {
                try await sleepBeforeRetry(attempt: attempt)
                attempt += 1
                continue
            } catch let error as Swift2MDError {
                throw error
            } catch {
                if shouldRetry(networkError: error, attempt: attempt) {
                    try await sleepBeforeRetry(attempt: attempt)
                    attempt += 1
                    continue
                }
                throw Swift2MDError.networkError(underlying: error)
            }
        }
    }

    private func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        guard attempt < maxRetryCount else { return false }
        return statusCode == 429 || statusCode >= 500
    }

    private func shouldRetry(networkError: Error, attempt: Int) -> Bool {
        guard attempt < maxRetryCount else { return false }
        if networkError is CancellationError { return false }

        guard let urlError = networkError as? URLError else { return false }
        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .notConnectedToInternet,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    private func sleepBeforeRetry(attempt: Int) async throws {
        let baseSeconds = max(0, retryBaseDelay.timeInterval)
        guard baseSeconds > 0 else { return }

        let delaySeconds = baseSeconds * pow(2.0, Double(attempt))
        let delayNanoseconds = UInt64(min(delaySeconds * 1_000_000_000, Double(UInt64.max)))
        try await Task.sleep(nanoseconds: delayNanoseconds)
    }
}

private struct RetryableRequestError: Error {
}

private struct APIEnvelope: Decodable {
    let result: [ConversionResult]
    let success: Bool
    let errors: [APIMessage]
    let messages: [APIMessage]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        result = try container.decodeIfPresent([ConversionResult].self, forKey: .result) ?? []
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        errors = try container.decodeIfPresent([APIMessage].self, forKey: .errors) ?? []
        messages = try container.decodeIfPresent([APIMessage].self, forKey: .messages) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case result
        case success
        case errors
        case messages
    }
}

private struct APIMessage: Decodable {
    let message: String

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let text = try? container.decode(String.self) {
            message = text
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? "Unknown API error"
    }

    private enum CodingKeys: String, CodingKey {
        case message
    }
}
