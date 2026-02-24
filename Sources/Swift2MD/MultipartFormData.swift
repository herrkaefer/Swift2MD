import Foundation

struct MultipartFormData {
    let boundary: String
    private(set) var body = Data()

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    mutating func addFile(data: Data, name: String, filename: String, mimeType: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    func finalize() -> Data {
        var finalized = body
        finalized.append(Data("--\(boundary)--\r\n".utf8))
        return finalized
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    private mutating func append(_ string: String) {
        body.append(Data(string.utf8))
    }
}
