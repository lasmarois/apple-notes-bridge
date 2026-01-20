import Foundation

/// Options for exporting notes
public struct ExportOptions {
    /// Include YAML frontmatter in Markdown export
    public var includeFrontmatter: Bool = true

    /// Include HTML content in JSON export
    public var includeHTML: Bool = false

    /// Include all metadata in JSON export (attachments, hashtags, noteLinks)
    public var fullMetadata: Bool = false

    /// Include attachments in export
    public var includeAttachments: Bool = true

    public init(
        includeFrontmatter: Bool = true,
        includeHTML: Bool = false,
        fullMetadata: Bool = false,
        includeAttachments: Bool = true
    ) {
        self.includeFrontmatter = includeFrontmatter
        self.includeHTML = includeHTML
        self.fullMetadata = fullMetadata
        self.includeAttachments = includeAttachments
    }

    /// Minimal export options
    public static var minimal: ExportOptions {
        ExportOptions(includeFrontmatter: false, includeHTML: false, fullMetadata: false)
    }

    /// Full export options
    public static var full: ExportOptions {
        ExportOptions(includeFrontmatter: true, includeHTML: true, fullMetadata: true)
    }
}

/// Protocol for note formatters (enables pluggable export formats)
public protocol NoteFormatter {
    /// Format a note for export
    /// - Parameters:
    ///   - note: The note content to format
    ///   - options: Export options
    /// - Returns: Formatted string representation
    func format(_ note: NoteContent, options: ExportOptions) throws -> String

    /// File extension for this format
    var fileExtension: String { get }
}
