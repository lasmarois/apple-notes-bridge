import Foundation

/// Parsed frontmatter metadata from a markdown file
public struct NoteFrontmatter {
    public var title: String?
    public var folder: String?
    public var tags: [String]
    public var created: Date?
    public var modified: Date?

    public init(
        title: String? = nil,
        folder: String? = nil,
        tags: [String] = [],
        created: Date? = nil,
        modified: Date? = nil
    ) {
        self.title = title
        self.folder = folder
        self.tags = tags
        self.created = created
        self.modified = modified
    }
}

/// Result of parsing a markdown file with frontmatter
public struct ParsedMarkdown {
    /// Extracted frontmatter metadata
    public let frontmatter: NoteFrontmatter

    /// Markdown content without frontmatter
    public let content: String

    /// Title extracted from frontmatter, # heading, or filename
    public let resolvedTitle: String
}

/// Parses YAML frontmatter from markdown files
public class FrontmatterParser {

    public init() {}

    /// Parse a markdown file and extract frontmatter
    /// - Parameters:
    ///   - markdown: The full markdown content including frontmatter
    ///   - filename: Optional filename to use as fallback title
    /// - Returns: ParsedMarkdown with frontmatter and content separated
    public func parse(_ markdown: String, filename: String? = nil) -> ParsedMarkdown {
        var frontmatter = NoteFrontmatter()
        var content = markdown

        // Check for frontmatter delimiter
        if markdown.hasPrefix("---") {
            let lines = markdown.components(separatedBy: "\n")
            var endIndex: Int?

            // Find closing ---
            for (index, line) in lines.enumerated().dropFirst() {
                if line.trimmingCharacters(in: .whitespaces) == "---" {
                    endIndex = index
                    break
                }
            }

            if let end = endIndex {
                // Extract frontmatter lines (between --- and ---)
                let frontmatterLines = Array(lines[1..<end])
                frontmatter = parseFrontmatterLines(frontmatterLines)

                // Content is everything after the closing ---
                let contentLines = Array(lines[(end + 1)...])
                content = contentLines.joined(separator: "\n")

                // Remove leading blank lines from content
                content = content.trimmingCharacters(in: CharacterSet.newlines.union(.init(charactersIn: " ")))
            }
        }

        // Resolve title: frontmatter > first # heading > filename
        let resolvedTitle = resolveTitle(
            frontmatter: frontmatter,
            content: content,
            filename: filename
        )

        return ParsedMarkdown(
            frontmatter: frontmatter,
            content: content,
            resolvedTitle: resolvedTitle
        )
    }

    // MARK: - Private Methods

    private func parseFrontmatterLines(_ lines: [String]) -> NoteFrontmatter {
        var frontmatter = NoteFrontmatter()

        for line in lines {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }

            let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "title":
                frontmatter.title = unquote(value)
            case "folder":
                frontmatter.folder = unquote(value)
            case "tags":
                frontmatter.tags = parseTags(value)
            case "created":
                frontmatter.created = parseDate(value)
            case "modified":
                frontmatter.modified = parseDate(value)
            default:
                break
            }
        }

        return frontmatter
    }

    private func unquote(_ value: String) -> String {
        var result = value
        if (result.hasPrefix("\"") && result.hasSuffix("\"")) ||
           (result.hasPrefix("'") && result.hasSuffix("'")) {
            result = String(result.dropFirst().dropLast())
        }
        // Unescape quotes
        result = result.replacingOccurrences(of: "\\\"", with: "\"")
        result = result.replacingOccurrences(of: "\\'", with: "'")
        return result
    }

    private func parseTags(_ value: String) -> [String] {
        // Handle YAML array format: [tag1, tag2] or tag1, tag2
        var cleaned = value
        if cleaned.hasPrefix("[") && cleaned.hasSuffix("]") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

        return cleaned
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { unquote($0) }
            .filter { !$0.isEmpty }
    }

    private func parseDate(_ value: String) -> Date? {
        // Try ISO8601 first
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: value) {
            return date
        }

        // Try without timezone
        iso8601.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        if let date = iso8601.date(from: value) {
            return date
        }

        // Try date only
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.date(from: value)
    }

    private func resolveTitle(frontmatter: NoteFrontmatter, content: String, filename: String?) -> String {
        // 1. Use frontmatter title if available
        if let title = frontmatter.title, !title.isEmpty {
            return title
        }

        // 2. Extract from first # heading
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    return title
                }
            }
            // Skip empty lines, but stop at first non-heading content
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                break
            }
        }

        // 3. Use filename without extension
        if let filename = filename {
            let name = (filename as NSString).deletingPathExtension
            if !name.isEmpty {
                return name
            }
        }

        // 4. Fallback
        return "Untitled"
    }
}
