import Foundation

/// Formats notes as JSON with configurable detail level
public class JSONFormatter: NoteFormatter {

    public init() {}

    public var fileExtension: String { "json" }

    /// Format a note as JSON
    public func format(_ note: NoteContent, options: ExportOptions) throws -> String {
        let exportNote = ExportableNote(from: note, options: options)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportNote)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ExportError.encodingFailed("Failed to encode JSON as UTF-8")
        }

        return json
    }
}

/// Represents a note for JSON export with configurable fields
private struct ExportableNote: Codable {
    let id: String
    let title: String
    let content: String
    let folder: String?
    let createdAt: Date?
    let modifiedAt: Date?

    // Optional fields based on options
    let htmlContent: String?
    let attachments: [ExportableAttachment]?
    let hashtags: [String]?
    let noteLinks: [ExportableNoteLink]?

    init(from note: NoteContent, options: ExportOptions) {
        self.id = note.id
        self.title = note.title
        self.content = note.content
        self.folder = note.folder
        self.createdAt = note.createdAt
        self.modifiedAt = note.modifiedAt

        // Include HTML if requested
        self.htmlContent = options.includeHTML ? note.htmlContent : nil

        // Include full metadata if requested
        if options.fullMetadata {
            self.attachments = note.attachments.map { ExportableAttachment(from: $0) }
            self.hashtags = note.hashtags.isEmpty ? nil : note.hashtags
            self.noteLinks = note.noteLinks.isEmpty ? nil : note.noteLinks.map { ExportableNoteLink(from: $0) }
        } else {
            self.attachments = nil
            self.hashtags = nil
            self.noteLinks = nil
        }
    }

    // Custom encoding to omit nil values
    enum CodingKeys: String, CodingKey {
        case id, title, content, folder, createdAt, modifiedAt
        case htmlContent, attachments, hashtags, noteLinks
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(folder, forKey: .folder)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(modifiedAt, forKey: .modifiedAt)
        try container.encodeIfPresent(htmlContent, forKey: .htmlContent)
        try container.encodeIfPresent(attachments, forKey: .attachments)
        try container.encodeIfPresent(hashtags, forKey: .hashtags)
        try container.encodeIfPresent(noteLinks, forKey: .noteLinks)
    }
}

private struct ExportableAttachment: Codable {
    let id: String
    let identifier: String
    let name: String?
    let typeUTI: String
    let fileSize: Int64

    init(from attachment: Attachment) {
        self.id = attachment.id
        self.identifier = attachment.identifier
        self.name = attachment.name
        self.typeUTI = attachment.typeUTI
        self.fileSize = attachment.fileSize
    }
}

private struct ExportableNoteLink: Codable {
    let text: String
    let targetId: String

    init(from link: NoteLink) {
        self.text = link.text
        self.targetId = link.targetId
    }
}

/// Errors that can occur during export
public enum ExportError: Error, LocalizedError {
    case encodingFailed(String)
    case fileWriteFailed(String)
    case noteNotFound(String)
    case invalidOutputPath(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let message):
            return "Encoding failed: \(message)"
        case .fileWriteFailed(let message):
            return "File write failed: \(message)"
        case .noteNotFound(let id):
            return "Note not found: \(id)"
        case .invalidOutputPath(let path):
            return "Invalid output path: \(path)"
        }
    }
}
