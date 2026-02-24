import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CloudflareClient: Sendable {
    let credentials: CloudflareCredentials
    let session: URLSession
    let timeout: Duration

    init(credentials: CloudflareCredentials, session: URLSession = .shared, timeout: Duration = .seconds(60)) {
        self.credentials = credentials
        self.session = session
        self.timeout = timeout
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

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Swift2MDError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Swift2MDError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(httpResponse.statusCode) else {
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
    }
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
