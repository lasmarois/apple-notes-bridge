import Foundation

/// Handles exporting notes to various formats
public class NotesExporter {
    private let database: NotesDatabase
    private let decoder: NoteDecoder

    public init(database: NotesDatabase) {
        self.database = database
        self.decoder = NoteDecoder()
    }

    // MARK: - Single Note Export

    /// Export a single note to a string
    public func exportNote(
        id: String,
        formatter: NoteFormatter,
        options: ExportOptions = ExportOptions()
    ) throws -> String {
        let note = try database.readNote(id: id, includeTables: true)
        return try formatter.format(note, options: options)
    }

    /// Export a single note with styled content (for better Markdown output)
    public func exportNoteStyled(
        id: String,
        options: ExportOptions = ExportOptions()
    ) throws -> String {
        let note = try database.readNote(id: id, includeTables: true)
        let styled = try getStyledContent(forNoteId: id)

        let formatter = MarkdownFormatter()
        return try formatter.formatStyled(note, styled: styled, options: options)
    }

    /// Export a single note to a file
    public func exportNoteToFile(
        id: String,
        formatter: NoteFormatter,
        outputPath: URL,
        options: ExportOptions = ExportOptions()
    ) throws {
        let content = try exportNote(id: id, formatter: formatter, options: options)
        try content.write(to: outputPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Batch Export

    /// Export all notes in a folder to a directory
    public func exportFolder(
        folderName: String,
        outputDirectory: URL,
        formatter: NoteFormatter,
        options: ExportOptions = ExportOptions(),
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> ExportResult {
        let notes = try database.listNotes(folder: folderName, limit: 100000)
        return try exportNotes(
            notes: notes,
            baseFolder: folderName,
            outputDirectory: outputDirectory,
            formatter: formatter,
            options: options,
            progress: progress
        )
    }

    /// Export all notes to a directory
    public func exportAll(
        outputDirectory: URL,
        formatter: NoteFormatter,
        options: ExportOptions = ExportOptions(),
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> ExportResult {
        let notes = try database.listNotes(limit: 100000)
        return try exportNotes(
            notes: notes,
            baseFolder: nil,
            outputDirectory: outputDirectory,
            formatter: formatter,
            options: options,
            progress: progress
        )
    }

    // MARK: - Private Methods

    private func exportNotes(
        notes: [Note],
        baseFolder: String?,
        outputDirectory: URL,
        formatter: NoteFormatter,
        options: ExportOptions,
        progress: ((Int, Int) -> Void)?
    ) throws -> ExportResult {
        var result = ExportResult()
        let total = notes.count

        // Create output directory if needed
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        // Create attachments directory if needed
        let attachmentsDir = outputDirectory.appendingPathComponent("attachments")
        if options.includeAttachments {
            try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        }

        for (index, noteSummary) in notes.enumerated() {
            do {
                let note = try database.readNote(id: noteSummary.id, includeTables: true)

                // Determine output path
                let relativePath = getRelativePath(for: note, baseFolder: baseFolder)
                let fileName = safeFilename(note.title) + ".\(formatter.fileExtension)"
                let outputPath = outputDirectory
                    .appendingPathComponent(relativePath)
                    .appendingPathComponent(fileName)

                // Create parent directory
                try FileManager.default.createDirectory(
                    at: outputPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                // Export note content
                let content: String
                if formatter is MarkdownFormatter, let mdFormatter = formatter as? MarkdownFormatter {
                    // Use styled export for Markdown
                    let styled = try getStyledContent(forNoteId: note.id)
                    content = try mdFormatter.formatStyled(note, styled: styled, options: options)
                } else {
                    content = try formatter.format(note, options: options)
                }

                try content.write(to: outputPath, atomically: true, encoding: .utf8)
                result.exportedNotes.append(outputPath)

                // Export attachments if requested
                if options.includeAttachments && !note.attachments.isEmpty {
                    let noteAttachmentsDir = attachmentsDir
                        .appendingPathComponent(relativePath)
                        .appendingPathComponent(safeFilename(note.title))

                    try exportAttachments(
                        note: note,
                        to: noteAttachmentsDir,
                        result: &result
                    )
                }

                result.successCount += 1
            } catch {
                result.failures.append(ExportFailure(
                    noteId: noteSummary.id,
                    title: noteSummary.title,
                    error: error.localizedDescription
                ))
            }

            progress?(index + 1, total)
        }

        return result
    }

    private func getRelativePath(for note: NoteContent, baseFolder: String?) -> String {
        guard let folder = note.folder else { return "" }

        if let base = baseFolder {
            // If exporting a specific folder, don't include it in path
            if folder == base {
                return ""
            }
            // If subfolder, use relative path
            if folder.hasPrefix(base + "/") {
                return String(folder.dropFirst(base.count + 1))
            }
        }

        return folder
    }

    private func safeFilename(_ name: String) -> String {
        var safe = name
        // Replace problematic characters
        let replacements: [(String, String)] = [
            ("/", "-"),
            (":", "-"),
            ("\"", ""),
            ("<", ""),
            (">", ""),
            ("|", "-"),
            ("?", ""),
            ("*", ""),
            ("\\", "-")
        ]

        for (from, to) in replacements {
            safe = safe.replacingOccurrences(of: from, with: to)
        }

        // Trim whitespace and limit length
        safe = safe.trimmingCharacters(in: .whitespaces)
        if safe.count > 200 {
            safe = String(safe.prefix(200))
        }

        // Handle empty name
        if safe.isEmpty {
            safe = "Untitled"
        }

        return safe
    }

    private func exportAttachments(
        note: NoteContent,
        to directory: URL,
        result: inout ExportResult
    ) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let appleScript = NotesAppleScript()

        for attachment in note.attachments {
            let filename = attachment.name ?? "attachment-\(attachment.identifier)"

            do {
                let sourcePath = try appleScript.getAttachmentPath(id: attachment.id)
                let sourceURL = URL(fileURLWithPath: sourcePath)
                let destURL = directory.appendingPathComponent(filename)

                // Remove existing file if present
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                result.exportedAttachments.append(destURL)
            } catch {
                result.failures.append(ExportFailure(
                    noteId: note.id,
                    title: "Attachment: \(filename)",
                    error: error.localizedDescription
                ))
            }
        }
    }

    private func getStyledContent(forNoteId id: String) throws -> StyledNoteContent {
        // This requires access to the raw note data
        // For now, return a basic styled content from the note text
        let note = try database.readNote(id: id, includeTables: true)

        // Create basic attribute run for the whole text
        let attributeRuns = [AttributeRun(length: note.content.count, styleType: .body)]

        return StyledNoteContent(
            text: note.content,
            attributeRuns: attributeRuns,
            tables: []
        )
    }
}

// MARK: - Export Result

/// Result of a batch export operation
public struct ExportResult {
    public var successCount: Int = 0
    public var exportedNotes: [URL] = []
    public var exportedAttachments: [URL] = []
    public var failures: [ExportFailure] = []

    public var failureCount: Int { failures.count }
    public var totalCount: Int { successCount + failureCount }
}

/// Information about a failed export
public struct ExportFailure {
    public let noteId: String
    public let title: String
    public let error: String
}
