import Foundation

/// Converts markdown text to HTML for Apple Notes
public class MarkdownConverter {

    public init() {}

    /// Convert markdown to HTML
    /// Handles: code blocks, inline code, bold, italic, strikethrough, headers, lists, blockquotes
    public func convert(_ markdown: String) -> String {
        var result = markdown

        // 1. First, handle fenced code blocks: ```lang\ncode\n```
        result = processCodeBlocks(result)

        // 2. Handle inline code: `code`
        result = processInlineCode(result)

        // 3. Escape HTML in non-code parts and restore code
        result = escapeAndRestoreCode(result)

        // 4. Process markdown formatting
        result = processFormatting(result)

        // 5. Handle line-based markdown (headers, lists, quotes)
        result = processLineBasedMarkdown(result)

        return result
    }

    // MARK: - Code Processing

    private func processCodeBlocks(_ text: String) -> String {
        var result = text
        let codeBlockPattern = "```(?:\\w*)?\\n([\\s\\S]*?)```"

        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)

            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let codeRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                let code = String(result[codeRange])
                let escapedCode = escapeHTMLInCode(code)
                    .replacingOccurrences(of: "\n", with: "<br>")

                let replacement = "⟦CODEBLOCK⟧\(escapedCode)⟦/CODEBLOCK⟧"
                result.replaceSubrange(fullRange, with: replacement)
            }
        }

        return result
    }

    private func processInlineCode(_ text: String) -> String {
        var result = text
        let inlinePattern = "`([^`]+)`"

        if let regex = try? NSRegularExpression(pattern: inlinePattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)

            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let codeRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                let code = String(result[codeRange])
                let escapedCode = escapeHTMLInCode(code)

                let replacement = "⟦CODE⟧\(escapedCode)⟦/CODE⟧"
                result.replaceSubrange(fullRange, with: replacement)
            }
        }

        return result
    }

    private func escapeAndRestoreCode(_ text: String) -> String {
        var escaped = ""
        var remaining = text

        while !remaining.isEmpty {
            let codeBlockRange = remaining.range(of: "⟦CODEBLOCK⟧")
            let codeRange = remaining.range(of: "⟦CODE⟧")

            let nextPlaceholder: (range: Range<String.Index>, isBlock: Bool)?
            if let cbr = codeBlockRange, let cr = codeRange {
                nextPlaceholder = cbr.lowerBound < cr.lowerBound ? (cbr, true) : (cr, false)
            } else if let cbr = codeBlockRange {
                nextPlaceholder = (cbr, true)
            } else if let cr = codeRange {
                nextPlaceholder = (cr, false)
            } else {
                nextPlaceholder = nil
            }

            guard let (startRange, isBlock) = nextPlaceholder else {
                escaped += escapeHTML(remaining)
                break
            }

            let before = String(remaining[..<startRange.lowerBound])
            escaped += escapeHTML(before)

            let afterStart = String(remaining[startRange.upperBound...])
            let endTag = isBlock ? "⟦/CODEBLOCK⟧" : "⟦/CODE⟧"

            if let endRange = afterStart.range(of: endTag) {
                let codeContent = String(afterStart[..<endRange.lowerBound])
                // Menlo font, dark red color for inline code only
                let fontTag = isBlock ? "<font face=\"Menlo\">" : "<font face=\"Menlo\" color=\"#c7254e\">"
                escaped += "\(fontTag)\(codeContent)</font>"
                remaining = String(afterStart[endRange.upperBound...])
            } else {
                escaped += escapeHTML(remaining)
                break
            }
        }

        return escaped
    }

    // MARK: - Formatting

    private func processFormatting(_ text: String) -> String {
        var result = text

        // Bold: **text** or __text__
        result = applyPattern(result, pattern: "\\*\\*(.+?)\\*\\*", replacement: "<b>$1</b>")
        result = applyPattern(result, pattern: "__(.+?)__", replacement: "<b>$1</b>")

        // Italic: *text* or _text_
        result = applyPattern(result, pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", replacement: "<i>$1</i>")
        result = applyPattern(result, pattern: "(?<![\\w])_(?!_)(.+?)(?<!_)_(?![\\w])", replacement: "<i>$1</i>")

        // Strikethrough: ~~text~~
        result = applyPattern(result, pattern: "~~(.+?)~~", replacement: "<strike>$1</strike>")

        return result
    }

    private func processLineBasedMarkdown(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")

        for i in 0..<lines.count {
            var line = lines[i]

            // Headers: # ## ###
            if line.hasPrefix("### ") {
                line = "<b>\(String(line.dropFirst(4)))</b>"
            } else if line.hasPrefix("## ") {
                line = "<b><span style=\"font-size: 18px\">\(String(line.dropFirst(3)))</span></b>"
            } else if line.hasPrefix("# ") {
                line = "<b><span style=\"font-size: 24px\">\(String(line.dropFirst(2)))</span></b>"
            }
            // Blockquotes: > text (note: > was escaped to &gt;)
            else if line.hasPrefix("&gt; ") {
                line = "<font color=\"#666666\">▎ \(String(line.dropFirst(5)))</font>"
            } else if line.hasPrefix("&gt;") && line.count > 4 {
                line = "<font color=\"#666666\">▎ \(String(line.dropFirst(4)))</font>"
            }
            // Unordered lists: - or *
            else if line.hasPrefix("- ") {
                line = "• \(String(line.dropFirst(2)))"
            } else if line.hasPrefix("* ") {
                line = "• \(String(line.dropFirst(2)))"
            }

            lines[i] = line
        }

        return lines.joined(separator: "<br>")
    }

    // MARK: - Helpers

    private func applyPattern(_ string: String, pattern: String, replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return string
        }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: replacement)
    }

    /// Escape HTML special characters
    public func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func escapeHTMLInCode(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
