import Foundation

/// File formats supported by Workers AI `toMarkdown`.
public enum SupportedFormat: String, CaseIterable, Sendable {
    case pdf
    case jpeg
    case png
    case webp
    case svg
    case html
    case xml
    case csv
    case docx
    case xlsx
    case xlsm
    case xlsb
    case xls
    case et
    case ods
    case odt
    case numbers

    /// MIME type used when uploading this format.
    public var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .jpeg: return "image/jpeg"
        case .png: return "image/png"
        case .webp: return "image/webp"
        case .svg: return "image/svg+xml"
        case .html: return "text/html"
        case .xml: return "application/xml"
        case .csv: return "text/csv"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .xlsm: return "application/vnd.ms-excel.sheet.macroEnabled.12"
        case .xlsb: return "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
        case .xls: return "application/vnd.ms-excel"
        case .et: return "application/vnd.ms-excel"
        case .ods: return "application/vnd.oasis.opendocument.spreadsheet"
        case .odt: return "application/vnd.oasis.opendocument.text"
        case .numbers: return "application/vnd.apple.numbers"
        }
    }

    /// Canonical file extension for this format.
    public var fileExtension: String { rawValue }

    /// Infers a supported format from a filename extension.
    public init?(filename: String) {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        if ext == "jpg" {
            self = .jpeg
            return
        }
        if ext == "htm" {
            self = .html
            return
        }
        self.init(rawValue: ext)
    }

    /// Infers a supported format from a MIME type.
    public init?(mimeType: String) {
        let normalized = mimeType.lowercased().split(separator: ";", maxSplits: 1).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "application/pdf":
            self = .pdf
        case "image/jpeg", "image/jpg":
            self = .jpeg
        case "image/png":
            self = .png
        case "image/webp":
            self = .webp
        case "image/svg+xml":
            self = .svg
        case "text/html", "application/xhtml+xml":
            self = .html
        case "application/xml", "text/xml":
            self = .xml
        case "text/csv", "application/csv":
            self = .csv
        case "application/vnd.ms-excel":
            self = .xls
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            self = .docx
        case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
            self = .xlsx
        case "application/vnd.ms-excel.sheet.macroenabled.12":
            self = .xlsm
        case "application/vnd.ms-excel.sheet.binary.macroenabled.12":
            self = .xlsb
        case "application/x-iwork-numbers-sffnumbers", "application/vnd.apple.numbers":
            self = .numbers
        case "application/vnd.oasis.opendocument.spreadsheet":
            self = .ods
        case "application/vnd.oasis.opendocument.text":
            self = .odt
        default:
            return nil
        }
    }
}
